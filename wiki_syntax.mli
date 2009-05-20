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
   Wiki AST to OcamlDuce
   @author Vincent Balat
*)

open Wiki_sql.Types


(** Define new extensions to the wiki syntax. *)
val add_extension : 
  name:string ->
  ?wiki_content:bool ->
  ( Wiki_widgets_interface.box_info ->
     (string * string) list -> 
       string option -> 
         (Xhtmltypes_duce.flows Lwt.t, 
          {{Eliom_duce.Blocks.a_content_elt_list}} Lwt.t,
          string * Wikicreole.attribs * 
            {{Eliom_duce.Blocks.a_content_elt_list}} Lwt.t)
           Wikicreole.ext_kind) -> 
  unit

val find_extension : name:string -> 
  bool * ( Wiki_widgets_interface.box_info ->
            (string * Eliom_duce.Xhtml.uri) list ->
              string option ->
                (Xhtmltypes_duce.flows Lwt.t, 
                 {{Eliom_duce.Blocks.a_content_elt_list}} Lwt.t,
                 string * Wikicreole.attribs * 
                   {{Eliom_duce.Blocks.a_content_elt_list}} Lwt.t)
                  Wikicreole.ext_kind)

(** Returns the XHTML corresponding to a wiki page.
    The int32 is the id of the wiki (a wikibox may contain another one,
    and the default wiki id is the same as the one of the surrounding box).
*)
val xml_of_wiki :
  Wiki_widgets_interface.box_info ->
  string -> 
  Xhtmltypes_duce.flows Lwt.t

(** returns only the content of the first paragraph of a wiki text.
*)
val inline_of_wiki :
  Wiki_widgets_interface.box_info ->
  string -> 
  Xhtmltypes_duce.inlines Lwt.t

(** returns only the content of the first paragraph of a wiki text,
    after having removed links.
*)
val a_content_of_wiki :
  Wiki_widgets_interface.box_info ->
  string -> 
  {{ [ Xhtmltypes_duce.a_content* ] }} Lwt.t

(** Returns the wiki syntax for an extension box
    from its name, arguments and content.
*)
val string_of_extension : 
  string -> (string * string) list -> string option -> string

(** parses common attributes ([class], [id]) *)
val parse_common_attribs : (string * string) list -> Xhtmltypes_duce.coreattrs

(** returns true if the string is an absolute URL (http://...) *)
val is_absolute_link : string -> bool


