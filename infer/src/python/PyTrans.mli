(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open! IStd

val to_module : sourcefile:Textual.SourceFile.t -> string -> FFI.Code.t -> Textual.Module.t
(** Translate a Python code object into its Textual counter part *)
