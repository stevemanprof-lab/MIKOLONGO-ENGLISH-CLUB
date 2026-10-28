-- MIKOLONGO ENGLISH CLUB : backend (à relire puis exécuter dans Supabase > SQL Editor)
create table club_settings(key text primary key, value text not null);
insert into club_settings values('club_code','21102026');
create table profiles(id uuid primary key references auth.users on delete cascade,
 last_name text not null, first_name text not null, class_name text not null, phone text unique not null,
 role text not null default 'student' check(role in('student','admin')),
 status text not null default 'active' check(status in('active','blocked')),
 created_at timestamptz default now(), last_seen_at timestamptz);
create table locked_units(unit_id text primary key);
create table sentence_progress(user_id uuid references auth.users on delete cascade, unit_id text, idx int,
 best_score int not null default 0, attempts int not null default 0, validated bool not null default false,
 updated_at timestamptz default now(), primary key(user_id,unit_id,idx));
create table activity(id bigint generated always as identity primary key, user_id uuid references auth.users on delete cascade,
 unit_id text, idx int, score int, passed bool, created_at timestamptz default now());
create table messages(id bigint generated always as identity primary key,
 recipient_id uuid references auth.users on delete cascade, body text not null, created_at timestamptz default now());
create index on activity(user_id, created_at desc);

create function is_admin() returns bool language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin' and status='active') $$;
create function is_active() returns bool language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and status='active') $$;

-- Inscription : le code du club est vérifié ICI (côté serveur), jamais dans le JavaScript.
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare m jsonb := new.raw_user_meta_data;
begin
 if coalesce(m->>'club_code','') <> (select value from club_settings where key='club_code') then
   raise exception 'invalid_club_code'; end if;
 insert into profiles(id,last_name,first_name,class_name,phone)
 values(new.id, trim(m->>'last_name'), trim(m->>'first_name'), trim(m->>'class_name'), m->>'phone');
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

alter table club_settings enable row level security; alter table profiles enable row level security;
alter table locked_units enable row level security; alter table sentence_progress enable row level security;
alter table activity enable row level security; alter table messages enable row level security;
create policy s_code on club_settings for select using(is_admin());
create policy p_sel on profiles for select using(id=auth.uid() or is_admin());
create policy p_upd on profiles for update using(is_admin());
create policy l_sel on locked_units for select using(auth.uid() is not null);
create policy l_adm on locked_units for all using(is_admin()) with check(is_admin());
create policy sp_sel on sentence_progress for select using(user_id=auth.uid() or is_admin());
create policy a_sel on activity for select using(user_id=auth.uid() or is_admin());
create policy m_sel on messages for select using(is_active() and (recipient_id is null or recipient_id=auth.uid()) or is_admin());
create policy m_adm on messages for all using(is_admin()) with check(is_admin());
-- Les élèves n'écrivent JAMAIS directement : uniquement via record_attempt().

create function record_attempt(p_unit text,p_idx int,p_score int) returns void language plpgsql security definer set search_path=public as $$
begin
 if not is_active() then raise exception 'blocked'; end if;
 if exists(select 1 from locked_units where unit_id=p_unit) then raise exception 'locked'; end if;
 if p_idx<0 or p_idx>=20 or p_score<0 or p_score>100 then raise exception 'invalid'; end if;
 insert into activity(user_id,unit_id,idx,score,passed) values(auth.uid(),p_unit,p_idx,p_score,p_score>=65);
 insert into sentence_progress as s(user_id,unit_id,idx,best_score,attempts,validated)
  values(auth.uid(),p_unit,p_idx,p_score,1,p_score>=65)
  on conflict(user_id,unit_id,idx) do update set best_score=greatest(s.best_score,p_score),
   attempts=s.attempts+1, validated=s.validated or p_score>=65, updated_at=now();
 update profiles set last_seen_at=now() where id=auth.uid();
end $$;

-- Classement : points = somme des meilleurs scores des phrases validées (max 20 000)
create function admin_board() returns table(id uuid,last_name text,first_name text,class_name text,phone text,status text,
 validated int,points int,attempts int,last_activity timestamptz) language sql security definer set search_path=public as $$
 select p.id,p.last_name,p.first_name,p.class_name,p.phone,p.status,
  coalesce(sum((s.validated)::int),0)::int, coalesce(sum(case when s.validated then s.best_score end),0)::int,
  coalesce(sum(s.attempts),0)::int, p.last_seen_at
 from profiles p left join sentence_progress s on s.user_id=p.id
 where is_admin() and p.role='student' group by p.id $$;

create function admin_clear_history(p_user uuid default null) returns void language plpgsql security definer set search_path=public as $$
begin if not is_admin() then raise exception 'forbidden'; end if;
 delete from sentence_progress where p_user is null or user_id=p_user;
 delete from activity where p_user is null or user_id=p_user; end $$;
create function admin_delete_student(p_user uuid) returns void language plpgsql security definer set search_path=public as $$
begin if not is_admin() then raise exception 'forbidden'; end if;
 if (select role from profiles where id=p_user)='admin' then raise exception 'cannot delete admin'; end if;
 delete from auth.users where id=p_user; end $$;
create function admin_set_password(p_user uuid,p_password text) returns void language plpgsql security definer set search_path=public,extensions as $$
begin if not is_admin() then raise exception 'forbidden'; end if;
 if length(p_password)<6 then raise exception 'too short'; end if;
 update auth.users set encrypted_password=crypt(p_password,gen_salt('bf')) where id=p_user; end $$;
create function admin_set_code(p_code text) returns void language plpgsql security definer set search_path=public as $$
begin if not is_admin() then raise exception 'forbidden'; end if;
 update club_settings set value=p_code where key='club_code'; end $$;

-- Premier administrateur : s'inscrire dans l'appli, puis exécuter (avec VOTRE numéro) :
-- update profiles set role='admin' where phone='0XXXXXXXX';
