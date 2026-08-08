let port =
  try int_of_string (Sys.getenv "PORT")
  with Not_found -> 8080

let html_escape s =
  let buf = Buffer.create (String.length s) in
  String.iter (function
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '&' -> Buffer.add_string buf "&amp;"
      | '"' -> Buffer.add_string buf "&quot;"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let page_html = function
  | None ->
    String.concat ""
      ["<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\">";
       "<title>marina</title><style>body{font-family:sans-serif;margin:2em}";
       "input{font-family:monospace;width:100%;padding:.5em;box-sizing:border-box}";
       "button{margin-top:.5em;padding:.5em 1em}</style></head><body>";
       "<h1>marina</h1><p>Solveur SAT. Proposition en BNF marina :</p>";
       "<form method=\"post\" action=\"/\">";
       "<input name=\"prop\" type=\"text\" placeholder=\"(a & b | c) -> d\">";
       "<button type=\"submit\">Évaluer</button></form></body></html>"]
  | Some (prop, result) ->
    String.concat ""
      ["<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\">";
       "<title>marina</title><style>body{font-family:sans-serif;margin:2em}";
       "input{font-family:monospace;width:100%;padding:.5em;box-sizing:border-box}";
       "button{margin-top:.5em;padding:.5em 1em}";
       "pre{background:#f5f5f5;padding:1em;border-radius:4px}</style></head><body>";
       "<h1>marina</h1><form method=\"post\" action=\"/\">";
       "<input name=\"prop\" type=\"text\" value=\"" ^ html_escape prop ^ "\">";
       "<button type=\"submit\">Évaluer</button></form>";
       "<pre>" ^ html_escape result ^ "</pre></body></html>"]

let url_decode s =
  let buf = Buffer.create (String.length s) in
  let i = ref 0 in
  let n = String.length s in
  while !i < n do
    match s.[!i] with
    | '+' -> Buffer.add_char buf ' '; incr i
    | '%' when !i + 2 < n ->
      (try
         let hex = String.sub s (!i + 1) 2 in
         Buffer.add_char buf (Char.chr (int_of_string ("0x" ^ hex)));
         i := !i + 3
       with _ -> Buffer.add_char buf '%'; incr i)
    | c -> Buffer.add_char buf c; incr i
  done;
  Buffer.contents buf

let find_prop body =
  let rec find = function
    | [] -> None
    | token :: tokens ->
      if Str.string_match (Str.regexp_string "prop=") token 0 then
        Some (url_decode (String.sub token 5 (String.length token - 5)))
      else find tokens
  in
  find (Str.split (Str.regexp "&") body)

let read_headers ic =
  let rec collect acc =
    match String.trim (input_line ic) with
    | "" -> List.rev acc
    | line -> collect (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  collect []

let content_length headers =
  let rec find = function
    | [] -> 0
    | header :: headers' ->
      let lheader = String.lowercase_ascii header in
      if Str.string_match (Str.regexp_string "content-length:") lheader 0 then
        (try int_of_string (String.trim (String.sub lheader 15 (String.length lheader - 15)))
         with _ -> 0)
      else find headers'
  in
  find headers

let respond oc code reason content_type body =
  output_string oc (String.concat ""
                      ["HTTP/1.1 "; code; " "; reason; "\r\n";
                       "Content-Type: "; content_type; "\r\n";
                       "Content-Length: "; string_of_int (String.length body); "\r\n";
                       "Connection: close\r\n\r\n";
                       body]);
  flush oc

let ok oc content_type body = respond oc "200" "OK" content_type body
let bad_request oc content_type body = respond oc "400" "Bad Request" content_type body
let not_found oc content_type body = respond oc "404" "Not Found" content_type body

let handle_client ic oc =
  try
    let request_line = String.trim (input_line ic) in
    let headers = read_headers ic in
    let (method_, path) =
      match Str.split (Str.regexp " +") request_line with
      | m :: p :: _ -> (m, p)
      | _ -> ("", "")
    in
    let body =
      let clen = content_length headers in
      if clen > 0 then
        let buf = Bytes.create clen in
        let rec fill done_ =
          if done_ >= clen then ()
          else
            let n = input ic buf done_ (clen - done_) in
            if n = 0 then () else fill (done_ + n)
        in
        fill 0;
        Bytes.to_string buf
      else ""
    in
    begin match (method_, path) with
      | "GET", "/healthz" -> ok oc "text/plain" "ok\n"
      | "GET", "/" -> ok oc "text/html" (page_html None)
      | "POST", "/" ->
        begin match find_prop body with
          | Some prop -> ok oc "text/html" (page_html (Some (prop, Marina.sat_str prop)))
          | None -> bad_request oc "text/plain" "Missing 'prop' parameter\n"
        end
      | _ -> not_found oc "text/plain" "Not found\n"
    end
  with End_of_file -> ()

let () =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen sock 5;
  prerr_endline (String.concat "" ["marina server listening on port "; string_of_int port]);
  while true do
    let (fd, _) = Unix.accept sock in
    try
      let ic = Unix.in_channel_of_descr fd in
      let oc = Unix.out_channel_of_descr fd in
      handle_client ic oc;
      close_out oc
    with _ -> ()
  done
