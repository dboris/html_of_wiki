(** Module Users.

    Users, authentication, protection.

    In this model, users and groups are the same concept. A group can
    belong to another group. We only distinguish, for practical
    matters, between "login enabled" users and "group only" users: the
    former has [Some] (eventually void) password, the latter has
    [None].

*)
open User_sql.Types

exception NotAllowed
exception BadPassword
exception BadUser
exception UseAuth of userid

(** Non atuthenticated users *)
val anonymous : userid

(** A user that belongs to all groups *)
val admin : userid

(** A user/group that does not belong to any group,
    and nobody can be put in it.  *)
val nobody : userid

(** A group containing all authenticated users (not groups) *)
val authenticated_users : userid

(** Information about a user. Return [nobody] if the user
    does not currently exists, and raises [User_sql.NotBasicUser]
    if the user does not correspond to a basic user. *)
val get_basicuser_by_login : string -> userid Lwt.t


val get_user_from_name: name:string -> user Lwt.t


(*
val get_user_name_by_id : userid -> string Lwt.t
val get_user_by_id : id:userid -> userdata Lwt.t
val get_user_fullname_by_id : userid -> string Lwt.t
*)


(** Creates a new user with given parameters,
    or returns the existing user without modification
    if [name] is already present. *)
val create_user:
  name:string ->
  pwd:pwd ->
  fullname:string ->
  ?email:string ->
  groups:user list ->
  ?test:(sp:Eliom_sessions.server_params ->
          sd:Ocsimore_common.session_data -> bool Lwt.t) ->
  unit ->
  userid Lwt.t

val create_unique_user:
  name:string ->
  pwd:pwd ->
  fullname:string ->
  ?email:string ->
  groups:user list ->
  (userid * string) Lwt.t


(* BY 2009-03-13: deactivated because update_data is deactivated. See this file *)
(*
val update_user_data:
  user:userdata ->
  ?pwd:pwd ->
  ?fullname:string ->
  ?email:string option ->
  ?groups: userid list ->
  unit ->
  unit Lwt.t
*)

val authenticate : name:string -> pwd:string -> userdata Lwt.t


val in_group :
  (?user:user ->
    group:user ->
    unit -> bool Lwt.t) Ocsimore_common.sd_sp

val add_to_group : user:user -> group:user -> unit Lwt.t

val user_list_of_string : string -> user list Lwt.t

(****)
val get_user_data : userdata Lwt.t Ocsimore_common.sd_sp

val get_user_id : userid Lwt.t Ocsimore_common.sd_sp

val get_user_name : string Lwt.t Ocsimore_common.sd_sp

val is_logged_on : bool Lwt.t Ocsimore_common.sd_sp

val set_session_data : (userid -> unit Lwt.t) Ocsimore_common.sd_sp


val anonymous_sd : Ocsimore_common.session_data
