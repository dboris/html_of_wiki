(* Ocsimore
 * http://www.ocsigen.org
 * Copyright (C) 2005-2009
 * Piero Furiesi - Jaap Boender - Vincent Balat - Boris Yakobowski -
 * CNRS - Université Paris Diderot Paris 7
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
These are all the services related to wikis

*)

open User_sql.Types
open Wiki_widgets_interface
open Wiki_sql.Types
let (>>=) = Lwt.bind

exception Operation_insufficient_permissions
exception Css_already_exists
exception Page_already_exists


(** Name of the administration wiki. This is the name that must
    be used when creating (or searching for) this wiki. If that
    name is changed, the database *must* be upgraded manually to
    reflect the change *)
let wiki_admin_name = "Adminwiki"

let get_admin_wiki () =
  Wiki_sql.get_wiki_info_by_name wiki_admin_name




(** A text suitable as the default text for a container page *)
let default_container_page =
  "= Ocsimore wikipage\r\n\r\n<<loginbox>>\r\n\r\n<<content>>"


let send_static_file sp wiki dir page =
  let g = apply_parameterized_group
    Wiki_data.wiki_wikiboxes_grps.grp_reader wiki in
  Users.in_group ~sp ~group:g () >>= function
    | true -> Eliom_predefmod.Files.send ~sp (dir^"/"^page)
    | false -> Lwt.fail Eliom_common.Eliom_404


let wikicss_service_handler wiki () =
  Wiki_sql.get_css_for_wiki wiki >>= function
    | None -> Lwt.fail Eliom_common.Eliom_404
    | Some css -> Lwt.return css

let wikipagecss_service_handler (wiki, page) () =
  Wiki_sql.get_css_for_wikipage wiki page >>= function
    | Some css -> Lwt.return css
    | None -> Lwt.fail Eliom_common.Eliom_404




(* a table containing the Eliom services generating pages
   for each wiki associated to an URL *)
module Servpages =
  Hashtbl.Make(struct
                 type t = wiki
                 let equal = (=)
                 let hash = Hashtbl.hash
               end)

let naservpages :
    (string,
     unit,
     [ `Nonattached of [ `Get ] Eliom_services.na_s ],
     [ `WithoutSuffix ],
     [ `One of string ] Eliom_parameters.param_name,
     unit,
     [`Registrable ]
    ) Eliom_services.service Servpages.t = Servpages.create 5
let servpages :
    (string list,
     unit,
     Eliom_services.get_service_kind,
     [ `WithSuffix ],
     [ `One of string list ] Eliom_parameters.param_name,
     unit,
     [ `Registrable ]
    ) Eliom_services.service Servpages.t = Servpages.create 5
let servwikicss :
    (unit,
     unit,
     [ `Attached of
         [ `Internal of [ `Service | `Coservice ] * [ `Get ]
         | `External ] Eliom_services.a_s ],
     [ `WithoutSuffix ],
     unit,
     unit,
     [ `Registrable ]
    ) Eliom_services.service Servpages.t = Servpages.create 5

let add_naservpage = Servpages.add naservpages
let add_servpage = Servpages.add servpages
let add_servwikicss = Servpages.add servwikicss
let find_naservpage = Servpages.find naservpages
let find_servpage k =
  try Some (Servpages.find servpages k)
  with Not_found -> None
let find_servwikicss k =
  try Some (Servpages.find servwikicss k)
  with Not_found -> None




(* Register the services for the wiki [wiki] *)
let register_wiki
    ?sp ~path ~(wikibox_widget:Wiki_widgets_interface.interactive_wikibox)
    ~wiki () =
  Ocsigen_messages.debug
    (fun () -> Printf.sprintf "Registering wiki %s (at path '%s')"
       (string_of_wiki wiki) (String.concat "/"  path));
  (* Registering the service with suffix for wikipages *)
  (* Note that Eliom will look for the service corresponding to
     the longest prefix. Thus it is possible to register a wiki
     at URL / and another one at URL /wiki and it works,
     whatever be the order of registration *)
  let servpage =
    Eliom_predefmod.Any.register_new_service ~path ?sp
      ~get_params:(Eliom_parameters.suffix (Eliom_parameters.all_suffix "page"))
      (fun sp path () ->
         let bi = Wiki_widgets_interface.default_bi sp in
         wikibox_widget#send_wikipage ~bi ~wiki
           ~page:(Ocsigen_lib.string_of_url_path ~encode:true path)
      )
  in
  add_servpage wiki servpage;

  (* the same, but non attached: *)
  let naservpage =
    Eliom_predefmod.Any.register_new_coservice' ?sp
      ~name:("display"^string_of_wiki wiki)
      ~get_params:(Eliom_parameters.string "page")
      (fun sp page () ->
         let path = Ocsigen_lib.remove_slash_at_beginning (Neturl.split_path page)
         in
         let page = Ocsigen_lib.string_of_url_path ~encode:true path in
         let bi = Wiki_widgets_interface.default_bi sp in
         wikibox_widget#send_wikipage ~bi ~wiki ~page
      )
  in
  add_naservpage wiki naservpage;

  let wikicss_service =
    Eliom_predefmod.CssText.register_new_service ?sp
      ~path:(path@["__ocsiwikicss"])
      ~get_params:Eliom_parameters.unit
      (fun _sp () () -> wikicss_service_handler wiki ())
  in
  add_servwikicss wiki wikicss_service


(* Creates and registers a wiki if it does not already exists  *)
let create_and_register_wiki ?sp ~wikibox_widget
    ~title ~descr ?path ?staticdir ?(boxrights = true)
    ~author
    ?(admins=[basic_user author]) ?(readers = [basic_user Users.anonymous])
    ?wiki_css ~container_text
    () =
  Lwt.catch
    (fun () ->
       Wiki_sql.get_wiki_info_by_name title
       >>= fun w -> Lwt.return w.wiki_id)
    (function
       | Not_found ->
           begin
             Wiki.really_create_wiki ~title ~descr ?path ?staticdir ~boxrights
               ~author ~admins ~readers ?wiki_css ~container_text ()
             >>= fun wiki_id ->
             (match path with
                | None -> ()
                | Some path ->
                    register_wiki ?sp ~path ~wikibox_widget ~wiki:wiki_id ()
             );
             Lwt.return wiki_id
           end
       | e -> Lwt.fail e)


let save_then_redirect override_wikibox ~sp f =
  Lwt.catch
    (fun () ->
       f ();
       (* We do a redirection to prevent repost *)
       Eliom_predefmod.Redirection.send ~sp Eliom_services.void_coservice'
    )
    (fun e ->
       Wiki_widgets_interface.set_override_wikibox
         ~sp
         (override_wikibox, Error e);
       Eliom_predefmod.Action.send ~sp ())

let services () =

let action_edit_css = Eliom_predefmod.Action.register_new_coservice'
  ~name:"css_edit"
  ~get_params:(eliom_wikibox_args **
                 (eliom_css_args **
                    (Eliom_parameters.opt (Eliom_parameters.string "css" **
                                            Eliom_parameters.int32 "version"))))
  (fun sp (wb, args) () -> 
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, EditCss args);
     Lwt.return ())

and action_edit_wikibox = Eliom_predefmod.Action.register_new_coservice'
  ~name:"wiki_edit" ~get_params:eliom_wikibox_args
  (fun sp wb () ->
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, EditWikitext wb);
     Lwt.return ())

and action_delete_wikibox = Eliom_predefmod.Any.register_new_coservice'
  ~name:"wiki_delete" ~get_params:eliom_wikibox_args
  (fun sp wb () ->
     save_then_redirect wb ~sp
       (fun () -> Wiki.save_wikitextbox ~sp ~wb ~content:None)
  )

and action_edit_wikibox_permissions =
  Eliom_predefmod.Action.register_new_coservice'
    ~name:"wiki_edit_perm" ~get_params:eliom_wikibox_args
    (fun sp wb () -> 
       Wiki_widgets_interface.set_override_wikibox
         ~sp
         (wb, EditPerms wb);
       Lwt.return ())

and action_wikibox_history = Eliom_predefmod.Action.register_new_coservice'
  ~name:"wikibox_history" ~get_params:eliom_wikibox_args
  (fun sp wb () -> 
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, History wb);
     Lwt.return ())

and action_css_history = Eliom_predefmod.Action.register_new_coservice'
  ~name:"css_history" ~get_params:(eliom_wikibox_args ** eliom_css_args)
  (fun sp (wb, css) () -> 
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, CssHistory css);
     Lwt.return ())

and action_old_wikibox = Eliom_predefmod.Action.register_new_coservice'
  ~name:"wiki_old_version"
  ~get_params:(eliom_wikibox_args ** (Eliom_parameters.int32 "version"))
  (fun sp (wb, _ver as arg) () ->
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, Oldversion arg);
     Lwt.return ())

and action_old_wikiboxcss = Eliom_predefmod.Action.register_new_coservice'
  ~name:"css_old_version"
  ~get_params:(eliom_wikibox_args **
                 (eliom_css_args ** (Eliom_parameters.int32 "version")))
  (fun sp (wb, (wbcss, version)) () ->
       Wiki_widgets_interface.set_override_wikibox
         ~sp
         (wb, CssOldversion (wbcss, version));
     Lwt.return ())

and action_src_wikibox = Eliom_predefmod.Action.register_new_coservice'
  ~name:"wiki_src"
  ~get_params:(eliom_wikibox_args ** (Eliom_parameters.int32 "version"))
  (fun sp (wb, _ver as arg) () -> 
     Wiki_widgets_interface.set_override_wikibox
       ~sp
       (wb, Src arg);
     Lwt.return ())

and action_send_wikiboxtext = Eliom_predefmod.Any.register_new_post_coservice'
  ~keep_get_na_params:false ~name:"wiki_save_wikitext"
  ~post_params:
  (Eliom_parameters.string "actionname" **
     ((eliom_wikibox_args ** Eliom_parameters.int32 "boxversion") **
        Eliom_parameters.string "content"))
  (fun sp () (actionname, (((wid, wbid as wb), boxversion), content)) ->
     (* We always show a preview before saving. Moreover, we check that the
        wikibox that the wikibox has not been modified in parallel of our
        modifications. If this is the case, we also show a warning *)
     Wiki.modified_wikibox wb boxversion
     >>= fun modified ->
       if actionname = "save" then
         match modified with
           | None ->
               Wiki_filter.preparse_extension (sp, wbid) wid content
               >>= fun content ->
               save_then_redirect wb ~sp
                 (fun () -> Wiki.save_wikitextbox ~sp ~wb
                    ~content:(Some content))
           | Some _ ->
               Wiki_widgets_interface.set_override_wikibox
                 ~sp
                 (wb, PreviewWikitext (wb, (content, boxversion)));
               Eliom_predefmod.Action.send ~sp ()
       else begin
         Wiki_widgets_interface.set_override_wikibox
           ~sp
           (wb, PreviewWikitext (wb, (content, boxversion)));
         Eliom_predefmod.Action.send ~sp ()
       end
      )

and action_send_css = Eliom_predefmod.Any.register_new_post_coservice'
  ~keep_get_na_params:false ~name:"wiki_save_css"
  ~post_params:
  ((eliom_wikibox_args ** (eliom_css_args **
                             Eliom_parameters.int32 "boxversion")) **
     Eliom_parameters.string "content")
  (fun sp () ((wb, ((wbcss, page), boxversion)), content) ->
     (* We always show a preview before saving. Moreover, we check that the
        wikibox that the wikibox has not been modified in parallel of our
        modifications. If this is the case, we also show a warning *)
     Wiki.modified_wikibox wbcss boxversion
     >>= fun modified ->
       match modified with
         | None ->
             save_then_redirect wb ~sp
               (fun () -> match page with
                  | None -> Wiki.save_wikicssbox ~sp
                      ~wiki:(fst wbcss) ~content:(Some content)
                  | Some page -> Wiki.save_wikipagecssbox ~sp
                      ~wiki:(fst wbcss) ~page ~content:(Some content)
               )
         | Some _ ->
             Wiki_widgets_interface.set_override_wikibox
               ~sp
               (wb, EditCss ((wbcss, page),
                             Some (content, boxversion)));
             Eliom_predefmod.Action.send ~sp ()
  )

and action_send_wikibox_permissions =
  fst (Users.GenericRights.helpers_admin_writer_reader
         ~prefix:"wiki" ~name:"edit-wikibox-permissions" Wiki_data.wikibox_grps
      ) ()

(* Below are the services for the css of wikis and wikipages.  The css
   at the level of wikis are registered in Wiki.ml *)

(* do not use this service, but the one below for css <link>s inside page *)
and _ = Eliom_predefmod.CssText.register_new_service
  ~path:[Ocsimore_lib.ocsimore_admin_dir; "pagecss"]
  ~get_params:(Eliom_parameters.suffix eliom_wikipage_args)
  (fun _sp -> wikipagecss_service_handler)


(* This is a non attached coservice, so that the css is in the same
   directory as the page. Important for relative links inside the css. *)
and pagecss_service = Eliom_predefmod.CssText.register_new_coservice'
  ~name:"pagecss" ~get_params:eliom_wikipage_args
  (fun _sp -> wikipagecss_service_handler)

and  _ = Eliom_predefmod.CssText.register_new_service
  ~path:[Ocsimore_lib.ocsimore_admin_dir; "wikicss"]
  ~get_params:(Wiki_sql.eliom_wiki "wiki")
  (fun _sp -> wikicss_service_handler)

and action_create_page = Eliom_predefmod.Action.register_new_post_coservice'
  ~name:"wiki_page_create" ~post_params:eliom_wikipage_args
  (fun sp () (wiki, page) ->
     Wiki_data.can_create_wikipages ~sp wiki
     >>= function
       | true ->
           Lwt.catch
             (fun () ->
                Wiki_sql.get_wikipage_info wiki page
                >>= fun { wikipage_dest_wiki = wid; wikipage_wikibox = wbid } ->
                  (* The page already exists. We display an error message
                     in the wikibox that should have contained the button
                     leading to the creation of the page. *)
                  let wb = (wid, wbid) in
                  Wiki_widgets_interface.set_override_wikibox
                    ~sp
                    (wb, Error Page_already_exists);
                  Lwt.return ()
             )
             (function
                | Not_found ->
                    Users.get_user_id ~sp
                    >>= fun user ->
                    Wiki.new_wikitextbox ~sp ~wiki ~author:user
                      ~comment:(Printf.sprintf "wikipage %s in wiki %s"
                                  page (string_of_wiki wiki))
                      ~content:("== Page "^page^"==") ()
                    >>= fun wbid ->
                    Wiki_sql.set_box_for_page ~sourcewiki:wiki ~wbid ~page ()
                    >>= fun () ->
                    Lwt.return ()
                | e -> Lwt.fail e)
       | false ->  Lwt.fail Ocsimore_common.Permission_denied
  )

and action_create_css = Eliom_predefmod.Action.register_new_coservice'
  ~name:"wiki_create_css"
  ~get_params:(eliom_wiki_args **
                  (Eliom_parameters.opt (Eliom_parameters.string "pagecss")))
  (fun sp (wiki, page) () ->
     Users.get_user_id ~sp
     >>= fun user ->
     (match page with
       | None -> Wiki_data.can_create_wikicss sp wiki
       | Some page -> Wiki_data.can_create_wikipagecss sp (wiki, page)
     ) >>= function
       | false -> Lwt.fail Ocsimore_common.Permission_denied
       | true ->
           let text = Some "" (* empty CSS by default *) in
           match page with
             | None -> (* Global CSS for the wiki *)
                 (Wiki_sql.get_css_for_wiki wiki >>= function
                    | None ->
                        Wiki_sql.set_css_for_wiki ~wiki ~author:user text
                    | Some _ -> Lwt.fail Css_already_exists
                 )

             | Some page -> (* Css for a specific wikipage *)
                 (Wiki_sql.get_css_for_wikipage ~wiki ~page >>= function
                    | None ->
                        Wiki_sql.set_css_for_wikipage ~wiki ~page
                          ~author:user text
                    | Some _ -> Lwt.fail Css_already_exists
                 )
  )


in (
  action_edit_css,
  action_edit_wikibox,
  action_delete_wikibox,
  action_edit_wikibox_permissions,
  action_wikibox_history,
  action_css_history,
  action_old_wikibox,
  action_old_wikiboxcss,
  action_src_wikibox,
  action_send_wikiboxtext,
  action_send_css,
  action_send_wikibox_permissions,
  pagecss_service,
  action_create_page,
  action_create_css
)
