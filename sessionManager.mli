module type IN = sig
  val url: string list
  val exit_link: Eliom.server_params -> [> Xhtmltypes.a ] XHTML.M.elt
  val default_groups: Users.user list
  val login_actions: Eliom.server_params -> Users.auth option -> unit
  val logout_actions: Eliom.server_params -> unit
  val registration_mail_from: string * string
  val registration_mail_subject: string
end

module type OUT = sig
  val mk_log_form: Eliom.server_params -> Users.auth option -> 
    [> Xhtmltypes.form ] XHTML.M.elt
end

module Make: functor (A: IN) -> OUT
