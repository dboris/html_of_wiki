(* Ocsimore
 * Copyright (C) 2005
 * Laboratoire PPS - Université Paris Diderot - CNRS
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)
(**
   @author Piero Furiesi
   @author Jaap Boender
   @author Vincent Balat
*)


type wiki_data = {
  wiki_id: Wiki_sql.wiki;
  comment: string;
  author: Users.userdata option;
  content: string;
  datetime: CalendarLib.Calendar.t;
}



class noneditable_wikibox :
  object

    method private display_error_box : string -> Xhtmltypes_duce.p

    method noneditable_wikibox :
      sp:Eliom_sessions.server_params ->
      sd:Ocsimore_common.session_data ->
      data:Wiki_sql.wiki * int32 ->
      Xhtmltypes_duce._div Lwt.t

    method private retrieve_data : Wiki_sql.wiki * int32 -> string Lwt.t

  end

class editable_wikibox :
  unit ->
  object

    method display_edit_box :
      sp:Eliom_sessions.server_params ->
      sd:Ocsimore_common.session_data ->
      ?rows:int ->
      ?cols:int ->
      classe:string ->
      Wiki_sql.wiki * int32 ->
      string ->
      Xhtmltypes_duce._div Lwt.t

    method display_editable_box :
      sp:Eliom_sessions.server_params ->
      ?error:Wiki.wiki_errors ->
      classe:string ->
      Wiki_sql.wiki * int32 ->
      string ->
      Xhtmltypes_duce._div Lwt.t

    method private display_error_box :
      string -> Xhtmltypes_duce.p

    method private display_error_message :
      Wiki.wiki_errors option -> {{ [Xhtmltypes_duce.p*] }}

    method display_history :
      sp:Eliom_sessions.server_params ->
      Wiki_sql.wiki * int32 ->
      (int32 * string * string * CalendarLib.Calendar.t) list ->
      Xhtmltypes_duce.inlines Lwt.t

    method display_history_box :
      sp:Eliom_sessions.server_params ->
      classe:string ->
      Wiki_sql.wiki * int32 ->
      ?first:int ->
      ?last:int ->
      (int32 * string * string * CalendarLib.Calendar.t) list ->
      Xhtmltypes_duce._div Lwt.t

    method display_noneditable_box :
      ?error:Wiki.wiki_errors ->
      classe:string ->
      string ->
      Xhtmltypes_duce._div Lwt.t

    method display_old_wikibox :
      sp:Eliom_sessions.server_params ->
      classe:string ->
      Wiki_sql.wiki * int32 ->
      string ->
      int32 ->
      Xhtmltypes_duce._div Lwt.t

    method editable_wikibox :
      sp:Eliom_sessions.server_params ->
      sd:Ocsimore_common.session_data ->
      data:Wiki_sql.wiki * int32 ->
      ?rows:int ->
      ?cols:int ->
      ?classe:string list ->
      unit ->
      Xhtmltypes_duce._div Lwt.t

    method private retrieve_history :
      sp:Eliom_sessions.server_params ->
      Wiki_sql.wiki * int32 ->
      ?first:int ->
      ?last:int ->
      unit -> (int32 * string * string * CalendarLib.Calendar.t) list Lwt.t

    method retrieve_old_wikibox_content :
      sp:Eliom_sessions.server_params ->
      Wiki_sql.wiki * int32 -> int32 -> string Lwt.t

    method retrieve_wikibox_content : Wiki_sql.wiki * int32 -> string Lwt.t

  end
