-- =====================================================================
--  Feuilles de temps — schéma Supabase
--  À coller dans Supabase > SQL Editor > New query, puis « Run ».
--  Peut être relancé sans danger sur un projet neuf.
-- =====================================================================

-- ---------- Profils (un par employé) ----------
-- Un employé existe dès que le bureau l'ajoute (nom seulement). S'il a un courriel,
-- il peut se créer un compte : le compte est alors lié à son profil (user_id).
create table if not exists public.profils (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid unique references auth.users(id) on delete set null,
  nom        text not null,
  courriel   text,                       -- facultatif ; permet à l'employé de se créer un compte
  matricule  text,                       -- matricule Employeur D
  taux       numeric(8,2),               -- taux horaire ($/h), pour les coûts de chantier
  role       text not null default 'employe' check (role in ('employe','admin')),
  actif      boolean not null default true,
  qbo_employee_id text,                  -- pour la synchro QuickBooks (phase 2)
  created_at timestamptz not null default now()
);
-- Mise à jour d'une base installée avec une version précédente (profil = compte)
alter table public.profils add column if not exists user_id uuid unique references auth.users(id) on delete set null;
alter table public.profils add column if not exists courriel text;
alter table public.profils drop constraint if exists profils_id_fkey;
alter table public.profils alter column id set default gen_random_uuid();
update public.profils p set user_id = p.id
  where p.user_id is null and exists (select 1 from auth.users u where u.id = p.id);
update public.profils p set courriel = u.email
  from auth.users u where u.id = p.user_id and p.courriel is null;
create unique index if not exists profils_courriel on public.profils (lower(courriel)) where courriel is not null;

-- Équipe de départ (seulement sur une base neuve)
insert into public.profils (nom, role)
select v.nom, v.role
from (values ('Victor', 'admin', 1), ('Denis', 'employe', 2), ('Edouard', 'employe', 3),
             ('Guewenn', 'employe', 4), ('Guilhem', 'employe', 5)) as v(nom, role, ordre)
where not exists (select 1 from public.profils)
order by v.ordre;

-- ---------- Chantiers ----------
create table if not exists public.chantiers (
  id          bigint generated always as identity primary key,
  nom         text not null,
  client      text,
  adresse     text,
  facturable  boolean not null default true,   -- valeur par défaut des heures sur ce chantier
  actif       boolean not null default true,
  qbo_customer_id text,                        -- pour la synchro QuickBooks (phase 2)
  created_at  timestamptz not null default now()
);

-- ---------- Codes de coût (nomenclature des travaux) ----------
create table if not exists public.codes_cout (
  code             text primary key,            -- ex. '06 11 00'
  libelle          text not null,
  description      text,
  division         text not null,               -- ex. '06'
  division_libelle text,                        -- ex. 'Bois, plastiques et composites'
  actif            boolean not null default true,
  ordre            int not null default 0,
  qbo_item_id      text,                        -- produit/service QuickBooks associé (phase 2)
  created_at       timestamptz not null default now()
);

-- Liste de départ. Les codes qui ne correspondent pas à des heures travaillées
-- (contingence, acomptes, assurance, locations) sont créés inactifs ; l'admin
-- peut les réactiver dans Gestion > Codes de coût.
insert into public.codes_cout (code, libelle, description, division, division_libelle, actif, ordre) values
  ('01 11 00', 'Conception et mise en route du projet', 'Conception et mise en route du projet : analyse préalable, relevés, plans préliminaires et démarrage du chantier.', '01', 'Exigences générales', true, 1),
  ('01 21 00', 'Contingence', 'Provision pour imprévus, selon les modalités prévues au contrat.', '01', 'Exigences générales', false, 2),
  ('01 26 13', 'Avenant', 'Modification au contrat : travaux additionnels ou modifiés, autorisés par avenant.', '01', 'Exigences générales', true, 3),
  ('01 29 00', 'Acomptes', 'Dépôt de garantie reçu à la signature du contrat, applicable au prix des travaux.', '01', 'Exigences générales', false, 4),
  ('01 30 00', 'Gestion de projet', 'Coordination des travaux, planification, supervision de chantier et suivi des sous-traitants.', '01', 'Exigences générales', true, 5),
  ('01 31 00', 'Assurance', 'Assurance chantier et cautionnement liés au projet.', '01', 'Exigences générales', false, 6),
  ('01 41 00', 'Permis', 'Obtention des permis municipaux : conformité, occupation du domaine public et autres autorisations.', '01', 'Exigences générales', true, 7),
  ('01 50 00', 'Ouvrages d''accès et protection temporaires', 'Installation et démontage des échafaudages, clôtures, protections temporaires et ouvrages d''accès au chantier.', '01', 'Exigences générales', true, 8),
  ('01 52 13', 'Location de toilette', 'Location et entretien d''une toilette de chantier pour la durée des travaux.', '01', 'Exigences générales', false, 9),
  ('01 54 00', 'Location d''équipements', 'Location de l''équipement et de la machinerie requis pour l''exécution des travaux.', '01', 'Exigences générales', false, 10),
  ('01 74 00', 'Nettoyage de chantier', 'Nettoyage périodique et nettoyage final du chantier à la livraison.', '01', 'Exigences générales', true, 11),
  ('01 74 19', 'Gestion des déchets', 'Conteneurs, transport et disposition des débris de construction, incluant le tri et la valorisation.', '01', 'Exigences générales', true, 12),
  ('02 41 00', 'Démolition', 'Démolition sélective des ouvrages existants, incluant la protection des éléments conservés.', '02', 'Conditions existantes', true, 13),
  ('02 80 00', 'Décontamination', 'Retrait et disposition des matériaux contaminés — amiante, moisissures, plomb — selon la réglementation applicable.', '02', 'Conditions existantes', true, 14),
  ('03 10 00', 'Coffrage et coulée de béton', 'Coffrage, armature et coulée des ouvrages de béton : semelles, dalles et murs de fondation.', '03', 'Béton', true, 15),
  ('04 20 00', 'Maçonnerie d''éléments', 'Maçonnerie de briques, blocs et pierres : montage, rejointoiement et réparation.', '04', 'Maçonnerie', true, 16),
  ('05 50 00', 'Ouvrages métalliques', 'Fabrication et installation d''ouvrages métalliques : linteaux, poutres, garde-corps et pièces sur mesure.', '05', 'Métaux', true, 17),
  ('06 10 53', 'Charpenterie diverse et fonds de clouage', 'Charpenterie diverse : fonds de clouage, renforts et ouvrages de bois secondaires.', '06', 'Bois, plastiques et composites', true, 18),
  ('06 11 00', 'Charpenterie (ossature et structure)', 'Ossature et structure de bois : murs, planchers, toits et éléments porteurs.', '06', 'Bois, plastiques et composites', true, 19),
  ('06 15 00', 'Charpenterie extérieure', 'Charpenterie extérieure : galeries, terrasses, pergolas et structures apparentes.', '06', 'Bois, plastiques et composites', true, 20),
  ('06 20 00', 'Menuiserie (finition intérieure)', 'Menuiserie de finition intérieure : moulures, plinthes, cadrages et boiseries.', '06', 'Bois, plastiques et composites', true, 21),
  ('06 26 00', 'Menuiserie (finition extérieure)', 'Menuiserie de finition extérieure : fascias, soffites, cadrages et ouvrages apparents.', '06', 'Bois, plastiques et composites', true, 22),
  ('06 43 00', 'Escalier', 'Fabrication et installation d''escaliers de bois : limons, marches, contremarches et garde-corps.', '06', 'Bois, plastiques et composites', true, 23),
  ('07 20 00', 'Isolation et étanchéité', 'Isolation thermique, pare-air et pare-vapeur de l''enveloppe du bâtiment.', '07', 'Isolation thermique et étanchéité', true, 24),
  ('07 30 00', 'Toiture de bardeau, tôle et tuiles', 'Couverture en bardeau d''asphalte, tôle ou tuiles, incluant sous-couche et solins.', '07', 'Isolation thermique et étanchéité', true, 25),
  ('07 46 00', 'Revêtement extérieur - murs et débords de toit', 'Revêtement extérieur des murs et des débords de toit, incluant fourrures et accessoires.', '07', 'Isolation thermique et étanchéité', true, 26),
  ('07 50 00', 'Toiture de membrane', 'Couverture de membrane élastomère ou TPO sur toit plat, incluant isolation et drains.', '07', 'Isolation thermique et étanchéité', true, 27),
  ('07 62 00', 'Pliage métallique', 'Solins, chapeaux et pièces de tôle pliée sur mesure.', '07', 'Isolation thermique et étanchéité', true, 28),
  ('08 05 00', 'Installation (ouvertures)', 'Installation des portes et fenêtres, incluant calfeutrage et finition du pourtour.', '08', 'Ouvertures et fermetures', true, 29),
  ('08 11 00', 'Portes extérieures et portes d''accès', 'Fourniture de portes extérieures et de portes d''accès, incluant la quincaillerie.', '08', 'Ouvertures et fermetures', true, 30),
  ('08 50 00', 'Fenêtres', 'Fourniture de fenêtres, incluant moustiquaires et accessoires.', '08', 'Ouvertures et fermetures', true, 31),
  ('08 80 00', 'Vitrages et miroirs', 'Fourniture et pose de vitrages, verre trempé et miroirs.', '08', 'Ouvertures et fermetures', true, 32),
  ('09 23 00', 'Plâtrerie d''intérieur', 'Plâtrage et réparation des surfaces de plâtre existantes.', '09', 'Finitions', true, 33),
  ('09 29 00', 'Revêtement de murs et plafonds (gypse)', 'Pose de gypse, tirage de joints et sablage, prêt à peindre.', '09', 'Finitions', true, 34),
  ('09 30 00', 'Travaux et fournitures de carreaux de céramique', 'Fourniture et pose de carreaux de céramique, porcelaine ou pierre, incluant membrane et coulis.', '09', 'Finitions', true, 35),
  ('09 60 00', 'Revêtements de sol', 'Fourniture et pose des revêtements de sol : bois, vinyle, sablage et vernissage.', '09', 'Finitions', true, 36),
  ('12 00 00', 'Ameublement et décoration', 'Fourniture de mobilier et d''éléments décoratifs.', '12', 'Ameublement et aménagement', true, 37),
  ('12 35 00', 'Rangement et mobilier intégré', 'Conception et installation de rangements et de mobilier intégré sur mesure.', '12', 'Ameublement et aménagement', true, 38),
  ('12 35 30.13', 'Cuisine', 'Fourniture et installation d''armoires de cuisine, comptoirs et quincaillerie.', '12', 'Ameublement et aménagement', true, 39),
  ('12 35 30.23', 'Vanités de salle de bain', 'Fourniture et installation de vanités, comptoirs et miroirs de salle de bain.', '12', 'Ameublement et aménagement', true, 40),
  ('22 00 00', 'Plomberie générale', 'Plomberie : alimentation, drainage, appareils sanitaires et raccordements.', '22', 'Plomberie', true, 41),
  ('23 20 00', 'Chauffage hydraulique', 'Chauffage hydraulique : chaudière, tuyauterie, radiateurs et planchers chauffants.', '23', 'Chauffage, ventilation et climatisation', true, 42),
  ('23 30 00', 'Ventilation', 'Ventilation mécanique : échangeur d''air, conduits, grilles et mise en service.', '23', 'Chauffage, ventilation et climatisation', true, 43),
  ('23 80 00', 'Chauffage et climatisation', 'Chauffage et climatisation : thermopompe, appareils, conduits et mise en service.', '23', 'Chauffage, ventilation et climatisation', true, 44),
  ('26 00 00', 'Électricité générale', 'Électricité : filage, panneau, circuits, appareillage et luminaires.', '26', 'Électricité', true, 45),
  ('26 05 21', 'Chauffage électrique', 'Chauffage électrique : plinthes, radiants, ventilo-convecteurs et thermostats.', '26', 'Électricité', true, 46),
  ('27 10 00', 'Télécommunication et multimédia', 'Câblage de télécommunication et multimédia : réseau, téléphonie et audiovisuel.', '27', 'Communications', true, 47),
  ('31 23 00', 'Excavation et remblais', 'Excavation, remblais, compactage et nivellement du site.', '31', 'Terrassement et préparation du site', true, 48),
  ('32 90 00', 'Revégétalisation et valorisation du site', 'Remise en état du terrain : nivellement, terre végétale, gazon et plantations.', '32', 'Aménagements extérieurs', true, 49),
  ('33 40 00', 'Gestion des eaux usées et des eaux pluviales', 'Drains, raccordements d''égout et gestion des eaux usées et pluviales.', '33', 'Services publics et réseaux', true, 50),
  ('99 00 00', 'Autres', 'Travaux hors nomenclature — préciser dans la description', '99', 'Autres', true, 51)
on conflict (code) do nothing;


-- ---------- Entrées de temps (une ligne = X heures, un jour, un chantier) ----------
create table if not exists public.entrees (
  id           bigint generated always as identity primary key,
  employe_id   uuid not null references public.profils(id) on delete cascade,
  date         date not null,
  chantier_id  bigint not null references public.chantiers(id),
  heures       numeric(5,2) not null check (heures > 0 and heures <= 24),
  facturable   boolean not null default true,
  note         text,
  statut       text not null default 'soumis' check (statut in ('soumis','approuve','refuse')),
  motif_refus  text,
  approuve_par uuid references public.profils(id),
  approuve_le  timestamptz,
  qbo_time_activity_id text,                   -- rempli quand envoyé à QuickBooks (phase 2)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
-- Transfert à QuickBooks : une fois rempli, l'entrée est verrouillée (elle sert à facturer).
-- « add column if not exists » permet de mettre à jour une base déjà installée.
alter table public.entrees add column if not exists exporte_qbo_le timestamptz;
alter table public.entrees add column if not exists exporte_qbo_par uuid references public.profils(id);
-- Code de coût de chaque entrée (obligatoire dans l'app ; vide pour les anciennes entrées)
alter table public.entrees add column if not exists code_cout text references public.codes_cout(code) on update cascade;
-- Nom exact du client/projet dans QuickBooks (ex. « Dupont:Rénovation cuisine »)
alter table public.chantiers add column if not exists qbo_nom text;
-- Une entrée peut avoir plusieurs lignes (code de coût + heures) : chaque ligne est
-- une rangée, et les rangées d'une même entrée partagent le même « groupe ».
-- Les anciennes rangées reçoivent chacune leur propre groupe.
alter table public.entrees add column if not exists groupe uuid not null default gen_random_uuid();
create index if not exists entrees_groupe on public.entrees (groupe);
create index if not exists entrees_employe_date on public.entrees (employe_id, date);
create index if not exists entrees_date on public.entrees (date);
create index if not exists entrees_chantier on public.entrees (chantier_id);

-- ---------- Paramètres de l'entreprise (une seule ligne) ----------
create table if not exists public.parametres (
  id            int primary key default 1 check (id = 1),
  nom_entreprise text default '',
  no_compagnie  text default '',   -- Employeur D : Paie > Paramètres de compagnie > Identification
  code_gain     text default '',   -- Employeur D : code de gain / no de relevé des heures régulières
  updated_at    timestamptz not null default now()
);
insert into public.parametres (id) values (1) on conflict (id) do nothing;

-- ---------- Absences (repère : pourquoi une journée n'a pas été travaillée) ----------
-- Aucune heure : rien ne va à la paie ni à QuickBooks.
create table if not exists public.absences (
  id          bigint generated always as identity primary key,
  employe_id  uuid not null references public.profils(id) on delete cascade,
  date        date not null,
  type        text not null check (type in ('maladie', 'conge', 'ferie')),
  created_at  timestamptz not null default now(),
  unique (employe_id, date)
);

-- =====================================================================
--  Fonctions utilitaires
-- =====================================================================

-- Profil de l'utilisateur connecté (null s'il n'a pas de profil actif)
create or replace function public.mon_profil()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.profils where user_id = auth.uid() and actif limit 1;
$$;

-- Vrai si l'utilisateur connecté est administrateur
create or replace function public.est_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.profils where user_id = auth.uid() and role = 'admin' and actif);
$$;

-- Quand un compte est créé (inscription ou invitation), on le lie au profil
-- qui porte le même courriel. Un courriel inconnu est refusé.
-- Le tout premier compte est lié au premier administrateur sans compte (Victor).
create or replace function public.creer_profil()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  p uuid;
begin
  select id into p from public.profils
    where user_id is null and courriel is not null and lower(courriel) = lower(new.email)
    limit 1;
  if p is null and not exists (select 1 from public.profils where user_id is not null) then
    select id into p from public.profils where user_id is null and role = 'admin' order by created_at limit 1;
    if p is null then
      insert into public.profils (nom, courriel, role, user_id)
      values (coalesce(nullif(new.raw_user_meta_data->>'nom', ''), split_part(new.email, '@', 1)), new.email, 'admin', new.id);
      return new;
    end if;
  end if;
  if p is null then
    raise exception 'Ce courriel n''est pas autorisé. Demande au bureau de t''ajouter dans l''app avec ce courriel.';
  end if;
  perform set_config('app.liaison_compte', 'oui', true);
  update public.profils set user_id = new.id, courriel = coalesce(courriel, new.email) where id = p;
  perform set_config('app.liaison_compte', '', true);
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.creer_profil();

-- Garde-fous sur les entrées :
--  - personne ne peut modifier une entrée transférée à QuickBooks
--    (l'admin doit d'abord annuler le transfert)
--  - seules les heures approuvées peuvent être transférées
--  - un employé peut modifier ses heures, même approuvées, tant qu'elles
--    ne sont pas dans QuickBooks ; l'entrée redevient alors « soumis »
--  - un employé ne peut pas approuver ni transférer
--  - une entrée transférée garde tout : heures, chantier, code, description, facturable
create or replace function public.garde_entrees()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.updated_at := now();

  if tg_op = 'UPDATE' and old.exporte_qbo_le is not null then
    if not public.est_admin() then
      raise exception 'Ces heures sont déjà dans QuickBooks et ne peuvent plus être modifiées.';
    end if;
    if new.exporte_qbo_le is not null
       and (new.employe_id, new.date, new.chantier_id, new.code_cout, new.heures, new.facturable, new.note, new.statut)
           is distinct from (old.employe_id, old.date, old.chantier_id, old.code_cout, old.heures, old.facturable, old.note, old.statut) then
      raise exception 'Ces heures sont déjà dans QuickBooks. Annule le transfert avant de les modifier.';
    end if;
  end if;

  if public.est_admin() then
    if new.exporte_qbo_le is not null and new.statut <> 'approuve' then
      raise exception 'Seules les heures approuvées peuvent être transférées à QuickBooks.';
    end if;
    if new.exporte_qbo_le is null then
      new.exporte_qbo_par := null;
    elsif tg_op = 'INSERT' or old.exporte_qbo_le is null then
      new.exporte_qbo_par := public.mon_profil();
    end if;
    if new.statut = 'approuve' and (tg_op = 'INSERT' or old.statut is distinct from 'approuve') then
      new.approuve_par := public.mon_profil();
      new.approuve_le  := now();
    elsif new.statut <> 'approuve' then
      new.approuve_par := null;
      new.approuve_le  := null;
    end if;
    return new;
  end if;

  -- Employé
  new.exporte_qbo_le  := null;
  new.exporte_qbo_par := null;
  new.employe_id   := public.mon_profil();
  new.statut       := 'soumis';
  new.motif_refus  := null;
  new.approuve_par := null;
  new.approuve_le  := null;
  -- l'employé choisit « facturable » ; l'admin le valide à l'approbation
  if tg_op = 'UPDATE' then
    new.qbo_time_activity_id := old.qbo_time_activity_id;
  else
    new.qbo_time_activity_id := null;
  end if;
  return new;
end;
$$;
drop trigger if exists garde_entrees on public.entrees;
create trigger garde_entrees
  before insert or update on public.entrees
  for each row execute function public.garde_entrees();

-- Un employé ne peut pas changer son propre rôle, taux ou matricule.
-- Le lien avec un compte (user_id) ne se fait qu'à la création du compte.
create or replace function public.garde_profils()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  -- Exceptions : la création d'un compte (liaison) et la suppression d'un compte
  -- dans Supabase (le lien est alors vidé automatiquement).
  if coalesce(current_setting('app.liaison_compte', true), '') <> 'oui'
     and not (new.user_id is null and old.user_id is not null
              and not exists (select 1 from auth.users u where u.id = old.user_id)) then
    new.user_id := old.user_id;
  end if;
  if not public.est_admin() then
    new.courriel := old.courriel;
    new.role := old.role;
    new.taux := old.taux;
    new.matricule := old.matricule;
    new.actif := old.actif;
    new.qbo_employee_id := old.qbo_employee_id;
  end if;
  return new;
end;
$$;
drop trigger if exists garde_profils on public.profils;
create trigger garde_profils
  before update on public.profils
  for each row execute function public.garde_profils();

-- =====================================================================
--  Sécurité ligne par ligne (RLS)
-- =====================================================================
alter table public.profils    enable row level security;
alter table public.chantiers  enable row level security;
alter table public.entrees    enable row level security;
alter table public.parametres enable row level security;
alter table public.codes_cout enable row level security;
alter table public.absences   enable row level security;

-- Profils
drop policy if exists profils_lecture on public.profils;
create policy profils_lecture on public.profils for select to authenticated
  using (user_id = auth.uid() or public.est_admin());
drop policy if exists profils_modif on public.profils;
create policy profils_modif on public.profils for update to authenticated
  using (user_id = auth.uid() or public.est_admin())
  with check (user_id = auth.uid() or public.est_admin());
drop policy if exists profils_ajout on public.profils;
create policy profils_ajout on public.profils for insert to authenticated
  with check (public.est_admin() and user_id is null);

-- Chantiers : tout le monde lit, l'admin gère
drop policy if exists chantiers_lecture on public.chantiers;
create policy chantiers_lecture on public.chantiers for select to authenticated using (true);
drop policy if exists chantiers_admin on public.chantiers;
create policy chantiers_admin on public.chantiers for all to authenticated
  using (public.est_admin()) with check (public.est_admin());

-- Entrées : chacun les siennes, l'admin toutes
drop policy if exists entrees_lecture on public.entrees;
create policy entrees_lecture on public.entrees for select to authenticated
  using (employe_id = public.mon_profil() or public.est_admin());
drop policy if exists entrees_ajout on public.entrees;
create policy entrees_ajout on public.entrees for insert to authenticated
  with check (employe_id = public.mon_profil() or public.est_admin());
drop policy if exists entrees_modif on public.entrees;
create policy entrees_modif on public.entrees for update to authenticated
  using ((employe_id = public.mon_profil() and exporte_qbo_le is null) or public.est_admin())
  with check (employe_id = public.mon_profil() or public.est_admin());
drop policy if exists entrees_suppr on public.entrees;
create policy entrees_suppr on public.entrees for delete to authenticated
  using (exporte_qbo_le is null and (employe_id = public.mon_profil() or public.est_admin()));

-- Paramètres : tout le monde lit, l'admin modifie
drop policy if exists parametres_lecture on public.parametres;
create policy parametres_lecture on public.parametres for select to authenticated using (true);
drop policy if exists parametres_admin on public.parametres;
create policy parametres_admin on public.parametres for update to authenticated
  using (public.est_admin()) with check (public.est_admin());

-- Codes de coût : tout le monde lit, l'admin gère
drop policy if exists codes_lecture on public.codes_cout;
create policy codes_lecture on public.codes_cout for select to authenticated using (true);
drop policy if exists codes_admin on public.codes_cout;
create policy codes_admin on public.codes_cout for all to authenticated
  using (public.est_admin()) with check (public.est_admin());

-- =====================================================================
--  Enregistrer une entrée et toutes ses lignes d'un seul coup
--  (tout passe ou rien ne passe ; les règles de sécurité s'appliquent)
--  p_lignes : [{"code_cout": "01 30 00", "heures": 4, "facturable": true,
--               "note": "Description des travaux pour ce code"}, ...]
--  Chaque ligne a sa propre description ; p_note sert seulement de valeur par défaut.
-- =====================================================================
create or replace function public.enregistrer_entree(
  p_groupe uuid, p_employe uuid, p_date date, p_chantier bigint, p_note text,
  p_lignes jsonb, p_statut text default null, p_motif text default null)
returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  g uuid := coalesce(p_groupe, gen_random_uuid());
  l jsonb;
  n int;
  total numeric := 0;
begin
  if p_lignes is null or jsonb_typeof(p_lignes) <> 'array' or jsonb_array_length(p_lignes) = 0 then
    raise exception 'Ajoute au moins une ligne (code de coût et heures).';
  end if;
  select coalesce(sum((x->>'heures')::numeric), 0) into total from jsonb_array_elements(p_lignes) x;
  if total > 24 then
    raise exception 'Le total de l''entrée dépasse 24 heures.';
  end if;
  if (select count(distinct x->>'code_cout') from jsonb_array_elements(p_lignes) x) < jsonb_array_length(p_lignes) then
    raise exception 'Le même code de coût apparaît deux fois dans l''entrée.';
  end if;

  if p_groupe is not null then
    if exists (select 1 from public.entrees where groupe = p_groupe and exporte_qbo_le is not null) then
      raise exception 'Ces heures sont déjà dans QuickBooks et ne peuvent plus être modifiées.';
    end if;
    delete from public.entrees where groupe = p_groupe;
    get diagnostics n = row_count;
    if n = 0 then
      raise exception 'Entrée introuvable ou non modifiable.';
    end if;
  end if;

  for l in select * from jsonb_array_elements(p_lignes) loop
    insert into public.entrees (groupe, employe_id, date, chantier_id, code_cout, heures, facturable, note, statut, motif_refus)
    values (g, p_employe, p_date, p_chantier, l->>'code_cout', (l->>'heures')::numeric,
            coalesce((l->>'facturable')::boolean, true), coalesce(nullif(trim(l->>'note'), ''), p_note), coalesce(p_statut, 'soumis'),
            case when p_statut = 'refuse' then p_motif end);
  end loop;
  return g;
end;
$$;
grant execute on function public.enregistrer_entree(uuid, uuid, date, bigint, text, jsonb, text, text) to authenticated;

-- Absences : chacun les siennes, l'admin toutes
drop policy if exists absences_lecture on public.absences;
create policy absences_lecture on public.absences for select to authenticated
  using (employe_id = public.mon_profil() or public.est_admin());
drop policy if exists absences_gestion on public.absences;
create policy absences_gestion on public.absences for all to authenticated
  using (employe_id = public.mon_profil() or public.est_admin())
  with check (employe_id = public.mon_profil() or public.est_admin());

-- =====================================================================
--  Connexion directe à QuickBooks Online
--  Les jetons d'accès ne sont lisibles QUE par la fonction serveur
--  « quickbooks » (clé secrète). L'app ne voit que le statut.
-- =====================================================================
alter table public.profils    add column if not exists qbo_type text check (qbo_type in ('Employee', 'Vendor'));
alter table public.codes_cout add column if not exists taux_facturation numeric(8,2);   -- $/h facturé pour ce code (sinon le taux par défaut)
alter table public.parametres add column if not exists taux_facturation numeric(8,2) default 90;
alter table public.parametres add column if not exists qbo_item_defaut text;            -- produit/service QuickBooks par défaut
alter table public.parametres add column if not exists qbo_item_defaut_nom text;

create table if not exists public.qbo_connexion (
  id             int primary key default 1 check (id = 1),
  realm_id       text not null,
  entreprise     text,
  environnement  text not null default 'production',
  access_token   text not null,
  access_expire  timestamptz not null,
  refresh_token  text not null,
  refresh_expire timestamptz,
  connecte_par   uuid references public.profils(id) on delete set null,
  connecte_le    timestamptz not null default now(),
  maj_le         timestamptz not null default now()
);
create table if not exists public.qbo_etats (
  etat       text primary key,
  profil_id  uuid references public.profils(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.qbo_connexion enable row level security;
alter table public.qbo_etats     enable row level security;
-- aucune règle d'accès : personne d'autre que la fonction serveur n'y touche
revoke all on public.qbo_connexion from anon, authenticated;
revoke all on public.qbo_etats     from anon, authenticated;

-- Statut de la connexion, sans les jetons (administrateurs seulement ; null sinon)
create or replace function public.qbo_statut()
returns jsonb
language sql stable security definer set search_path = public
as $$
  select case when not public.est_admin() then null else (
    select jsonb_build_object(
      'connecte', true, 'entreprise', c.entreprise, 'realm_id', c.realm_id,
      'environnement', c.environnement, 'connecte_le', c.connecte_le,
      'refresh_expire', c.refresh_expire,
      'connecte_par', (select nom from public.profils p where p.id = c.connecte_par))
    from public.qbo_connexion c where c.id = 1) end;
$$;
grant execute on function public.qbo_statut() to authenticated;
