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

open Eliom_pervasives
open User_sql.Types
open Wiki_widgets_interface
open Wiki_types
open Ocsimore_lib.Lwt_ops

(**/**)

let unopt_media_type = function
  | Some x -> x
  | None -> raise (Invalid_argument "media_type_elem_of_string")

let desugar_messages = Eliom_references.eref ~scope:Eliom_common.request []

let override_wikibox_eref = Eliom_references.eref ~scope:Eliom_common.request None

(** How to change the display of a wikibox: which wikibox is concerned,
   and what should be displayed instead *)
let get_override_wikibox () =
  Eliom_references.get override_wikibox_eref

let set_override_wikibox v =
  Eliom_references.set override_wikibox_eref (Some v)

let wikibox_error_eref =
  Eliom_references.eref ~scope:Eliom_common.request None

(** The error to display in the wikibox *)
let get_wikibox_error () =
  Eliom_references.get wikibox_error_eref

let set_wikibox_error v =
  Eliom_references.set wikibox_error_eref (Some v)

(**/**)

let send_wikipage
  ~(rights : Wiki_types.wiki_rights)
  ~wiki
  ?(menu_style=`Linear)
  ~page
  () =
  let wiki_page () =
    lwt wiki_info = Wiki_sql.get_wiki_info_by_id wiki in
    let widgets = Wiki_models.get_widgets wiki_info.wiki_model in
    lwt (html,code) =
      widgets#display_wikipage ~wiki ~sectioning:false ~menu_style ~page in
    Ocsimore_appl.send ~code html
  in
  Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
  (* if there is a static page, and should we send it ? *)
  match wiki_info.wiki_staticdir with
    | Some dir ->
      let filename = (dir ^"/"^ fst page) in
      if Eliom_output.Files.check_file filename
      then
        (match_lwt rights#can_view_static_files wiki with (*RRR: This should be generalized and exported *)
          | false -> Lwt.fail Ocsimore_common.Permission_denied (* XXX We should send a 403. ? *)
          | true -> Eliom_output.appl_self_redirect Eliom_output.Files.send filename)
      else wiki_page ()
    | None -> wiki_page ()


(** Register the services for the wiki [wiki] *)
let register_wiki ~rights ?sp ~path ~wiki ~siteids () =
  if fst siteids = snd siteids then (
  Ocsigen_messages.debug
    (fun () -> Printf.sprintf "Registering wiki %s (at path '%s')"
       (string_of_wiki wiki) (String.concat "/"  path));

  Wiki_self_services.insert_into_registered_wikis_tree wiki path;

  (* Registering the service with suffix for wikipages *)
  (* Note that Eliom will look for the service corresponding to
     the longest prefix. Thus it is possible to register a wiki
     at URL / and another one at URL /wiki and it works,
     whatever be the order of registration *)
  let servpage =
    Eliom_output.Any.register_service
      ~path
      ~get_params:(Eliom_parameters.suffix (Eliom_parameters.all_suffix "page"))
      (fun path () ->
         let page' = Url.string_of_url_path ~encode:false path in
         send_wikipage ~menu_style:`Pencil ~rights ~wiki ~page:(page', path) ()
      )
  in
  Wiki_self_services.add_servpage wiki servpage;

  (* the same, but non attached: *)
  let naservpage =
    Eliom_output.Any.register_coservice'
      ~name:("display"^string_of_wiki wiki)
      ~get_params:(Eliom_parameters.string "page")
      (fun page () ->
         let path =
           Url.remove_slash_at_beginning (Neturl.split_path page)
         in
         let page' = Url.string_of_url_path ~encode:false path in
         send_wikipage ~menu_style:`Pencil ~rights ~wiki ~page:(page', path) ()
      )
  in
  Wiki_self_services.add_naservpage wiki naservpage;

  let wikicss_service =
    Eliom_output.CssText.register_service
      ~path:(path@["__wikicss"])
      ~get_params:(Eliom_parameters.list "wblist" (Ocsimore_common.eliom_opaque_int32 "wb"))
      ~options:(3600 * 24 * 7) (* TODO parametrize *)
      (fun wblist () ->
         Wiki_data.wiki_css rights wiki >>= fun l ->
         let get_content wb = let (v, _, _) = List.assoc wb l in v in
         try Lwt.return (String.concat "\n\n" (List.map get_content wblist))
         with Not_found -> Lwt.fail Eliom_common.Eliom_404
      )
  in
  Wiki_self_services.add_servwikicss wiki wikicss_service
  )



let save_then_redirect ?(error=(fun _ -> Lwt.return ())) redirect_mode f =
  try_lwt
     lwt _ = f () in
     (* We do a redirection to prevent repost *)
     match redirect_mode with
       | `BasePage -> Eliom_output.Redirection.send
           Eliom_services.void_coservice'
       | `SamePage -> Eliom_output.Redirection.send
           Eliom_services.void_hidden_coservice'
  with e ->
     lwt () = error e in
     Eliom_output.Action.send ()

let error_handler_wb_opt wb e =
  set_wikibox_error (wb, e)

let error_handler_wb wb = error_handler_wb_opt (Some wb)


let ( ** ) = Eliom_parameters.prod

let eliom_wiki : string -> wiki Ocsimore_common.eliom_usertype =
  Ocsimore_common.eliom_opaque_int32
let eliom_wikibox : string -> wikibox Ocsimore_common.eliom_usertype =
  Ocsimore_common.eliom_opaque_int32

let eliom_wiki_args = eliom_wiki "wid"
let eliom_wikibox_args = eliom_wikibox "wbid"
let eliom_wikipage_args = eliom_wiki_args ** (Eliom_parameters.string "page")
let eliom_css_args =
  (eliom_wiki "widcss" **
   Eliom_parameters.opt (Eliom_parameters.string "pagecss"))
  ** eliom_wikibox "wbcss"

let add_remove_to_string = function
  | `Add -> "add"
  | `Remove -> "remove"
let eliom_add_remove = Eliom_parameters.user_type
  ~of_string:(function
                | "add" -> `Add
                | "remove" -> `Remove
                | _ -> failwith "incorrect action add/remove")
  ~to_string:add_remove_to_string


(* Services *)


open Wiki



let action_edit_css = Eliom_output.Action.register_coservice'
  ~name:"css_edit"
  ~get_params:(eliom_wikibox_args **
                 (eliom_css_args **
                    (Eliom_parameters.opt(Eliom_parameters.string "css" **
                                            Eliom_parameters.int32 "version"))))
  (fun (wb, args) () ->
     set_override_wikibox (wb, EditCss args))

and action_edit_css_list = Eliom_output.Action.register_coservice'
  ~name:"list_css_edit"
  ~get_params:(eliom_wikibox_args **
                 (eliom_wiki_args **
                    Eliom_parameters.opt (Eliom_parameters.string "pagecss")))
  (fun (wb, args) () ->
     set_override_wikibox (wb, EditCssList args))


and action_edit_wikibox = Eliom_output.Action.register_coservice'
  ~name:"wiki_edit" ~get_params:eliom_wikibox_args
  (fun wb () ->
     set_override_wikibox (wb, EditWikitext wb))

and action_delete_wikibox = Eliom_output.Any.register_coservice'
  ~name:"wiki_delete" ~get_params:eliom_wikibox_args
  (fun wb () ->
     Wiki_sql.wikibox_wiki wb >>= fun wiki ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     let content_type =
       Wiki_models.get_default_content_type wiki_info.wiki_model in
     save_then_redirect ~error:(error_handler_wb wb) `BasePage
       (fun () -> Wiki_data.save_wikitextbox ~rights ~content_type ~wb
          ~content:None)
  )

and action_edit_wikibox_permissions =
  Eliom_output.Action.register_coservice'
    ~name:"wikibox_edit_perm" ~get_params:eliom_wikibox_args
    (fun wb () ->
       set_override_wikibox (wb, EditWikiboxPerms wb))

and action_edit_wiki_options =
  Eliom_output.Action.register_coservice'
    ~name:"wiki_edit_options"
    ~get_params:(eliom_wikibox_args ** eliom_wiki_args)
    (fun (wb, wiki) () ->
       set_override_wikibox (wb, EditWikiOptions wiki))

and action_wikibox_history = Eliom_output.Action.register_coservice'
  ~name:"wikibox_history" ~get_params:eliom_wikibox_args
  (fun wb () ->
     set_override_wikibox (wb, History wb))

and action_css_history = Eliom_output.Action.register_coservice'
  ~name:"css_history" ~get_params:(eliom_wikibox_args ** eliom_css_args)
  (fun (wb, css) () ->
     set_override_wikibox (wb, CssHistory css))

and action_css_permissions = Eliom_output.Action.register_coservice'
  ~name:"css_edit_perm" ~get_params:(eliom_wikibox_args ** eliom_css_args)
  (fun (wb, css) () ->
     set_override_wikibox (wb, CssPermissions css))

and action_old_wikibox = Eliom_output.Action.register_coservice'
  ~name:"wiki_old_version"
  ~get_params:(eliom_wikibox_args ** (Eliom_parameters.int32 "version"))
  (fun (wb, _ver as arg) () ->
     set_override_wikibox (wb, Oldversion arg))

and action_old_wikiboxcss = Eliom_output.Action.register_coservice'
  ~name:"css_old_version"
  ~get_params:(eliom_wikibox_args **
                 (eliom_css_args ** (Eliom_parameters.int32 "version")))
  (fun (wb, (wbcss, version)) () ->
     set_override_wikibox (wb, CssOldversion (wbcss, version)))

and action_src_wikibox = Eliom_output.Action.register_coservice'
  ~name:"wiki_src"
  ~get_params:(eliom_wikibox_args ** (Eliom_parameters.int32 "version"))
  (fun (wb, _ver as arg) () ->
     set_override_wikibox (wb, Src arg))

and action_edit_wikipage_properties = Eliom_output.Action.register_coservice'
  ~name:"wikipage_properties"
  ~get_params:(eliom_wikibox_args ** eliom_wikipage_args)
  (fun (wb, wp) () ->
     set_override_wikibox (wb, EditWikipageProperties wp))

and action_send_wikiboxtext =
  let post_params =
    let open Eliom_parameters in
    let action = string "actionname" in
    let page_wiki = eliom_wiki "page_wiki" in
    let page_path = 
      let none_page_path = user_type (fun _ -> ()) (fun _ -> "") "empty_page_path" in
      let some_page_path = list "page_path" (string "page_path_snippet") in
      sum none_page_path some_page_path
    in
    let wb = eliom_wikibox_args in
    let boxversion = int32 "boxversion" in
    let content = string "content" in
    action ** ((page_wiki ** page_path) ** ((wb ** boxversion) ** content))
  in
  Eliom_output.Any.register_post_coservice'
    ~keep_get_na_params:false ~name:"wiki_save_wikitext" ~post_params
    (fun () (actionname, ((page_wiki, page_path), ((wb, boxversion), content))) ->
       (* We always show a preview before saving. Moreover, we check that the
          wikibox that the wikibox has not been modified in parallel of our
          modifications. If this is the case, we also show a warning *)
       Wiki_sql.wikibox_wiki wb >>= fun wiki ->
       Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
       let rights = Wiki_models.get_rights wiki_info.wiki_model in
       Wiki_data.wikibox_content rights wb >>= fun (content_type, _, _) ->
       let wpp = Wiki_models.get_default_wiki_preprocessor wiki_info.wiki_model in
       Wiki.modified_wikibox wb boxversion >>= fun modified ->
       if actionname = "save" && modified = None then (
         Wiki_models.preparse_string wpp wb content >>= fun content ->
         save_then_redirect ~error:(error_handler_wb wb) `BasePage
           (fun () -> Wiki_data.save_wikitextbox ~rights
              ~content_type ~wb ~content:(Some content))
       ) else (
         let desugar_context = {
           Wiki_syntax_types.dc_page_wiki = page_wiki;
           dc_page_path = Eliom_parameters.(match page_path with Inj1 _ -> None | Inj2 path -> Some path);
           dc_warnings = [];
         } in
         Wiki_models.desugar_string wpp desugar_context content >>= fun content ->
         Printf.eprintf "There are %d warnings" (List.length desugar_context.Wiki_syntax_types.dc_warnings);
         Eliom_references.set desugar_messages desugar_context.Wiki_syntax_types.dc_warnings >>= fun () ->
         lwt () = set_override_wikibox (wb, PreviewWikitext (wb, (content, boxversion))) in
         Eliom_output.Action.send ()
       )
    )

and action_send_css = Eliom_output.Any.register_post_coservice'
  ~keep_get_na_params:false ~name:"wiki_save_css"
  ~post_params:
  ((eliom_wikibox_args ** (eliom_css_args **
                             Eliom_parameters.int32 "boxversion")) **
     Eliom_parameters.string "content")
  (fun () ((wb, (((wikicss, page), wbcss), boxversion)), content) ->
     (* As above, we check that the wikibox has not been modified in parallel
        of our modifications. If this is the case, we also show a warning *)
     Wiki.modified_wikibox wbcss boxversion >>= fun modified ->
       match modified with
         | None ->
             Wiki_sql.wikibox_wiki wbcss >>= fun wiki ->
             Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
             let rights = Wiki_models.get_rights wiki_info.wiki_model in
             save_then_redirect ~error:(error_handler_wb wb) `BasePage
               (fun () -> match page with
                  | None -> Wiki_data.save_wikicssbox ~rights
                      ~wiki:wikicss ~content:(Some content) ~wb:wbcss
                  | Some page -> Wiki_data.save_wikipagecssbox ~rights
                      ~wiki:wikicss ~page ~content:(Some content) ~wb:wbcss
               )
         | Some _ ->
             lwt () =
               set_override_wikibox
                 (wb, EditCss (((wikicss, page), wbcss),
                               Some (content, boxversion)))
             in
             Eliom_output.Action.send ()
  )

and action_set_wikibox_special_permissions =
  Eliom_output.Any.register_post_coservice'
    ~name:"wiki_set_wikibox_special_permissions"
    ~post_params:(eliom_wikibox_args ** Ocsimore_lib.eliom_bool "special")
    (fun () (wb, special_rights) ->
       Wiki_sql.wikibox_wiki wb >>= fun wiki ->
       Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
       let rights = Wiki_models.get_rights wiki_info.wiki_model in
       save_then_redirect ~error:(error_handler_wb wb)
         (if special_rights then `SamePage else `BasePage)
         (fun () -> Wiki_data.set_wikibox_special_rights
            ~rights ~special_rights ~wb)
    )


(* Below are the service for the css of a wikipage.  The css
   at the level of wikis are stored in Wiki_self_services and
   registered in Wiki_data.ml *)

(* This is a non attached coservice, so that the css is in the same
   directory as the page. Important for relative links inside the css. *)
and pagecss_service = Eliom_output.CssText.register_coservice'
  ~name:"pagecss" ~get_params:(eliom_wikipage_args ** Eliom_parameters.list "wblist" eliom_wikibox_args)
  ~options:(3600 * 24 * 7) (* TODO parametrize *)
  (fun ((wiki, page), wblist) () ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     Wiki_data.wikipage_css rights wiki page >>= fun l ->
     let get_content wb = let (v, _, _) = List.assoc wb l in v in
     try Lwt.return (String.concat "\n\n" (List.map get_content wblist))
     with Not_found -> Lwt.fail Eliom_common.Eliom_404
  )

and action_create_page = Eliom_output.Action.register_post_coservice'
  ~name:"wiki_page_create"
  ~post_params:(Eliom_parameters.opt eliom_wikibox_args **eliom_wikipage_args)
  (fun () (wb, (wiki, page)) ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     try_lwt
       Wiki_data.create_wikipage ~rights ~wiki ~page
     with
        | Wiki_data.Page_already_exists wb ->
            (* The page already exists. If possible, we display an error
               message in the existing wikibox, which should have
               contained the button leading to the creation of the page. *)
            set_wikibox_error  (Some wb,
                                    Wiki_data.Page_already_exists wb)

        | Ocsimore_common.Permission_denied ->
            set_wikibox_error (wb, Ocsimore_common.Permission_denied)
        | e -> Lwt.fail e)

and action_create_css = Eliom_output.Any.register_post_coservice'
  ~name:"wiki_create_css" ~keep_get_na_params:true
  ~post_params:(eliom_wikibox_args **
                  ((eliom_wiki_args **
                      Eliom_parameters.opt (Eliom_parameters.string "pagecss"))
                   ** (Eliom_parameters.set
                         (Eliom_parameters.user_type
                            ~of_string:(fun x ->
                              unopt_media_type
                                (Wiki_types.media_type_elem_of_string x)
                            )
                            ~to_string:Wiki_types.string_of_media_type_elem
                         )
                         "media"
                       ** Ocsimore_common.eliom_opaque_int32_opt "wbcss")))
  (fun () (wb, ((wiki, page), (media, wbcss))) ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     save_then_redirect ~error:(error_handler_wb wb) `SamePage
       (fun () ->
          Wiki_data.add_css ~rights ~wiki ~page ~media ?wbcss ())
  )

and action_send_css_options = Eliom_output.Any.register_post_coservice'
  ~name:"wiki_send_css_options" ~keep_get_na_params:true
  ~post_params:(eliom_wikibox_args **
                (((eliom_css_args ** Eliom_parameters.opt
                                       (eliom_wikibox "newwbcss")) **
                  (Eliom_parameters.set
                     (Eliom_parameters.user_type
                         ~of_string:(fun x ->
                              unopt_media_type
                                (Wiki_types.media_type_elem_of_string x)
                            )
                         ~to_string:Wiki_types.string_of_media_type_elem
                     )
                     "media"))
                ** Eliom_parameters.int32 "rank"))
  (fun () (wb, (((((wiki, page), wbcss), newwbcss), media), rank)) ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     save_then_redirect ~error:(error_handler_wb wb) `SamePage
       (fun () ->
          match newwbcss with
            | None -> Wiki_data.delete_css ~rights ~wiki ~page ~wb:wbcss
            | Some newwb ->
                Wiki_data.update_css ~rights ~wiki ~page ~oldwb:wbcss
                  ~newwb:newwb ~media ~rank)
  )

and edit_wiki = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir;"edit_wiki"]
  ~get_params:eliom_wiki_args ()

and view_wikis = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir;"view_wikis"]
  ~get_params:Eliom_parameters.unit ()

and view_boxes = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir;"view_boxes"]
  ~get_params:eliom_wiki_args ()

and view_box = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir;"view_boxes"]
  ~get_params:(eliom_wikibox_args ** Eliom_parameters.(opt (int32 "version"))) ()

and batch_edit_boxes = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir; "batch_edit_boxes"]
  ~get_params:Eliom_parameters.unit ()

and action_send_wikipage_properties =
  Eliom_output.Any.register_post_coservice'
    ~keep_get_na_params:false ~name:"wikipage_save_properties"
    ~post_params:
    (eliom_wikibox_args **
       (eliom_wikipage_args **
          (Eliom_parameters.string "title" **
             ((Ocsimore_common.eliom_opaque_int32_opt "wb" **
                 Eliom_parameters.string "newpage")))))
    (fun () (wb, ((wiki, page), (title, (wbpage, newpage)))) ->
       Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
       let rights = Wiki_models.get_rights wiki_info.wiki_model in
       save_then_redirect ~error:(error_handler_wb wb) `BasePage
         (fun () -> Wiki_data.save_wikipage_properties ~rights
            ~title ~wb:wbpage ~newpage (wiki, page))
    )

and action_send_wiki_metadata = Eliom_output.Any.register_post_coservice'
  ~keep_get_na_params:false ~name:"wiki_save_metadata"
  ~post_params:
  (Eliom_parameters.opt eliom_wikibox_args **
     (eliom_wiki_args **
        (Eliom_parameters.string "descr" **
           Ocsimore_common.eliom_opaque_int32_opt "container")))
  (fun () (wb, (wiki, (descr, container))) ->
     Wiki_sql.get_wiki_info_by_id wiki >>= fun wiki_info ->
     let rights = Wiki_models.get_rights wiki_info.wiki_model in
     save_then_redirect ~error:(error_handler_wb_opt wb) `BasePage
       (fun () -> Wiki_data.update_wiki ~rights ~container ~descr wiki)
  )

and edit_wiki_permissions_admin = Eliom_services.service
  ~path:[!Ocsimore_config.admin_dir;"edit_wikis_permissions"]
  ~get_params:eliom_wiki_args ()
