(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open! IStd
module F = Format
open Textual
open TextualTestHelpers

let%expect_test _ =
  let no_lang = {|define nothing() : void { #node: ret null }|} in
  let m = parse_module no_lang in
  try TextualSil.module_to_sil m |> ignore
  with TextualTransformError errs ->
    List.iter errs ~f:(Textual.pp_transform_error sourcefile F.std_formatter) ;
    [%expect
      {| dummy.sil, <unknown location>: transformation error: Missing or unsupported source_language attribute |}]


let%expect_test "undefined types are included in tenv" =
  let source =
    {|
          .source_language = "hack"
          type Foo {}
          define Foo.f(arg1: Foo, arg2: Bar) : void { #n: ret null }
          declare Foo.undef() : void
          define Bar.f() : void {
            #entry:
              ret null
          }
          define g() : void {
            local l1: *Quux
            #n:
              n0 = __sil_allocate(<Baz>)
              ret null
          }
          |}
  in
  let m = parse_module source in
  let _, tenv = TextualSil.module_to_sil m in
  F.printf "%a@\n" Tenv.pp tenv ;
  [%expect
    {|
         hack Foo
         fields: {}
         statics: {}
         supers: {}
         objc_protocols: {}
         methods: {
                     Foo.f
                     Foo.undef
                   }
         exported_obj_methods: {}
         annots: {<>}
         java_class_info: {[None]}
         dummy: false
         hack Quux
         fields: {}
         statics: {}
         supers: {}
         objc_protocols: {}
         methods: {}
         exported_obj_methods: {}
         annots: {<>}
         java_class_info: {[None]}
         dummy: true
         hack Baz
         fields: {}
         statics: {}
         supers: {}
         objc_protocols: {}
         methods: {}
         exported_obj_methods: {}
         annots: {<>}
         java_class_info: {[None]}
         dummy: true
         hack Bar
         fields: {}
         statics: {}
         supers: {}
         objc_protocols: {}
         methods: {
                     Bar.f
                   }
         exported_obj_methods: {}
         annots: {<>}
         java_class_info: {[None]}
         dummy: false |}]


let%expect_test "unknown formal calls" =
  let source =
    {|
         .source_language = "hack"
         declare unknown(...) : *HackMixed
         declare known(*HackInt) : void

         define foo(x: *Foo, y: *HackInt) : void {
         #b0:
           n0: *HackMixed = load &x
           n1 = unknown(n0)
           n2: *HackMixed = load &y
           n3 = known(n2)
           ret null
         }
         |}
  in
  let m = parse_module source in
  let cfg, _ = TextualSil.module_to_sil m in
  Cfg.iter_sorted cfg ~f:(fun pdesc ->
      F.printf "%a" (Procdesc.pp_with_instrs ~print_types:true) pdesc ) ;
  [%expect
    {|
        { proc_name= foo
        ; translation_unit= dummy.sil
        ; formals= [(x,Foo*);  (y,HackInt*)]
        ; is_defined= true
        ; loc= dummy.sil:6:16
        ; locals= []
        ; ret_type= void
        ; proc_id= foo }
            #n1:

            #n3:
              n$0=*&x:HackMixed* [line 8, column 11];
              n$1=_fun_unknown(n$0:HackMixed*) [line 9, column 11];
              n$2=*&y:HackMixed* [line 10, column 11];
              n$3=_fun_known(n$2:HackInt*) [line 11, column 11];
              *&return:void=0 [line 12, column 11];

            #n2: |}]
