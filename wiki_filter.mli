(* Ocsimore
 * Copyright (C) 2008
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
   Filtering wiki syntax to perform special actions
   (before saving it to the database)
   @author Vincent Balat
*)

(**/**)
(** The filters registered with that function are called on
    the wikibox content before registering it in the database.
    Done automatically by [Wiki_syntax.add_extension]
*)
val add_preparser_extension :
  name:string ->
  ( Eliom_sessions.server_params * Wiki_sql.Types.wikibox,
    string option Lwt.t)
  Wikicreole.plugin_args -> unit

(** Filters the wiki syntax and replace extensions according to
    preparsers recorded with [add_preparser_extension].
*)
val preparse_extension :
  (Eliom_sessions.server_params * Wiki_sql.Types.wikibox) ->
  string -> string Lwt.t


type syntax_extension =
    (Wiki_widgets_interface.box_info,
     Xhtmltypes_duce.flows Lwt.t,
     Eliom_duce.Blocks.a_content_elt_list Lwt.t)
   Wikicreole.plugin


val extension_table : (string, bool * syntax_extension) Hashtbl.t

val find_extension : name:string -> bool * syntax_extension


(**/**)

