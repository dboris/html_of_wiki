(* Ocsimore
 * http://www.ocsigen.org
 * Copyright (C) 2011
 * Grégoire Henry
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

type 'a resolver = 'a -> Ocsigen_local_files.resolved
exception Undefined

val resolve_file_in_dir:
    ?default:string -> ?suffix:string -> string -> string list resolver

type 'a wrapper =
    'a
    -> Wiki_widgets_interface.box_info
    -> HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list
    -> (string * HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) Lwt.t

val make_wrapper_of_wikibox:
    ?title:string -> wb:Wiki_types.wikibox -> 'a wrapper

val process:
    wiki_id:Wiki_types.wiki ->
    resolve_wiki_file:('a resolver) ->
    ?resolve_wiki_menu_file:(string list resolver) ->
    ?err404:(Wiki_widgets_interface.box_info -> 'a -> HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) ->
    ?err403:(Wiki_widgets_interface.box_info -> 'a -> HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) ->
    ?css:(HTML5_types.link Eliom_pervasives.HTML5.M.elt list) ->
    ?wrapper:('a wrapper) ->
    unit ->
    'a -> unit -> HTML5_types.html Eliom_pervasives.HTML5.M.elt  Lwt.t

val make_page:
  wiki_id:Wiki_types.wiki
  -> ?css: (HTML5_types.link Eliom_pervasives.HTML5.M.elt list)
  -> (Wiki_widgets_interface.box_info
      -> (string * HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) Lwt.t)
  -> HTML5_types.html Eliom_pervasives.HTML5.M.elt Lwt.t
