(* Ocsimore
 * Copyright (C) 2009
 * Laboratoire PPS - Universit� Paris Diderot - CNRS
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
   @author Vincent Balat
   @author Boris Yakobowski
*)

let (>>=) = Lwt.bind


(*VVV mettre �a ailleurs *)
let widget_err = new Widget.widget_with_error_box
let message_widget = new Forum_widgets.message_widget widget_err
let thread_widget = new Forum_widgets.thread_widget widget_err message_widget

let _ =
  Wiki_syntax.add_block_extension "forum_message"
    (fun wiki_id bi args content -> 
       let classe = 
         try Some [List.assoc "class" args]
         with Not_found -> None
       in
       try
         let sp = bi.Wiki_syntax.bi_sp in
         let sd = bi.Wiki_syntax.bi_sd in
         let message_id = Int32.of_string (List.assoc "message" args) in
         message_widget#display ~commentable:false  ~sp ~sd ?classe
           ~data:message_id () >>= fun b ->
         Lwt.return {{ [ {: b :} ] }}
       with Not_found | Failure _ -> 
         let s = Wiki_syntax.string_of_extension "raw" args content in
         Lwt.return {{ [ <b>{: s :} ] }}
    )

let _ =
  Wiki_syntax.add_block_extension "forum_thread"
    (fun wiki_id bi args content ->
       let classe = 
         try Some [List.assoc "class" args]
         with Not_found -> None
       in
       try
         let sp = bi.Wiki_syntax.bi_sp in
         let sd = bi.Wiki_syntax.bi_sd in
         let message_id = Int32.of_string (List.assoc "message" args) in
         thread_widget#display ~commentable:true ~sp ~sd ?classe
           ~data:message_id () >>= fun b ->
         Lwt.return {{ [ {: b :} ] }}
       with Not_found | Failure _ -> 
         let s = Wiki_syntax.string_of_extension "raw" args content in
         Lwt.return {{ [ <b>{: s :} ] }}
    )
