(** An alias for the services that are accepted in the admin menu. *)
type menu_link_service =
    (Eliom_services.get_service_kind,
     [ `Unregistrable | `Registrable ])
    Eliom_tools_common.one_page


module type PageSig = sig


(** The service that answers for Ocsimore static files. *)
val static_service :
  ((string list, unit, Eliom_services.get_service_kind, [ `WithSuffix ],
    [ `One of string list ] Eliom_parameters.param_name, unit,
    [ `Registrable ])
   Eliom_services.service)

(** Path to a static file, suitable for inclusion in a <a> tag *)
val static_file_uri :
  sp:Eliom_sessions.server_params -> path:string list -> Eliom_duce.Xhtml.uri


(** Allows to add HTML headers required by page components *)
module Header : sig

    type header

    (** Define a new header *)
    val create_header : 
      (Eliom_sessions.server_params -> {{ [ Xhtmltypes_duce.head_misc* ] }})
      -> header
    
    (** Call this function every time you need a header to be included
        in the page. If this function is called several times for the same
        page with the same header, the header will be included only once.
    *)
    val require_header : header -> sp:Eliom_sessions.server_params -> unit

    (** This function is called to generate the headers for one page.
        Only required headers are included.
    *)
    val generate_headers : 
      sp:Eliom_sessions.server_params -> {{ [ Xhtmltypes_duce.head_misc* ] }}

  end

(** Function to be called when Obrowser is used inside a page.
    The relevant javascript files will be included *)
val add_obrowser_header : sp:Eliom_sessions.server_params -> unit

(** Function to be called on admin pages, and which add the
    relevant css (including for the admin menu) *)
val add_admin_pages_header : sp:Eliom_sessions.server_params -> unit


(** Registers the string passed as argument so that it is called
    when the onload event on the body tag of the page fires. The
    string must thus be well-formed javascript (without ; at the end) *)
val add_onload_function: Eliom_sessions.server_params -> string -> unit

(** Generic headers for an html page. The arguments [css] is added
    after the links resulting from the hooks added by the function
    [add_html_header_hook] above. The argument [body_classes] is
    used for the classes of the [body] html element. *)
val html_page :
  sp:Eliom_sessions.server_params ->
  ?body_classes:string list ->
  ?css:Xhtmltypes_duce.links ->
  ?title:string ->
  Xhtmltypes_duce.blocks ->
  Xhtmltypes_duce.html Lwt.t


(** Functions related to the administration menu *)


(** Adds an entire subsection, labelled by [name] to the admin menu.
    The service [root] is used to represent this section.
*)
val add_to_admin_menu :
  name:string ->
  links:(string * menu_link_service) list ->
  root:menu_link_service ->
  unit

(** The admin menu itself. The option [service] parameter is the service
    currently active, which will be displayed in a different way *)
val admin_menu:
  ?service:menu_link_service ->
  Eliom_sessions.server_params ->
  Xhtmltypes_duce.blocks


val admin_page:
  sp:Eliom_sessions.server_params ->
  service:menu_link_service ->
  ?body_classes:string list ->
  ?css:Xhtmltypes_duce.links ->
  ?title:string ->
  Xhtmltypes_duce.blocks ->
  Xhtmltypes_duce.html Lwt.t


val icon:
  sp:Eliom_sessions.server_params ->
  path:string ->
  text:string ->
  {{ [Xhtmltypes_duce.img*]}}


val add_status_function:
  (sp:Eliom_sessions.server_params -> Xhtmltypes_duce.flows Lwt.t) -> unit

end
