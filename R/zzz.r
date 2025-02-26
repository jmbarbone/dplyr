.onLoad <- function(libname, pkgname) {
  ns_dplyr <- ns_env(pkgname)

  op <- options()
  op.dplyr <- list(
    dplyr.show_progress = TRUE
  )
  toset <- !(names(op.dplyr) %in% names(op))
  if (any(toset)) options(op.dplyr[toset])

  .Call(dplyr_init_library, ns_dplyr, ns_env("vctrs"), ns_env("rlang"))

  # TODO: For `arrange()`, `group_by()`, and `with_order()` until vctrs changes
  # `vec_order()` to the new ordering algorithm and officially exports
  # `vec_order_base()`, at which point we should use `vec_order()` and
  # `vec_order_base()` directly and remove this.
  env_bind(
    .env = ns_dplyr,
    vec_order_base = import_vctrs("vec_order_base"),
    vec_order_radix = import_vctrs("vec_order_radix")
  )

  run_on_load()

  invisible()
}

.onAttach <- function(libname, pkgname) {
  setHook(packageEvent("plyr", "attach"), function(...) {
    packageStartupMessage(rule())
    packageStartupMessage(
      "You have loaded plyr after dplyr - this is likely ",
      "to cause problems.\nIf you need functions from both plyr and dplyr, ",
      "please load plyr first, then dplyr:\nlibrary(plyr); library(dplyr)"
    )
    packageStartupMessage(rule())
  })
}

.onDetach <- function(libpath) {
  setHook(packageEvent("plyr", "attach"), NULL, "replace")
}

import_vctrs <- function(name) {
  import_from(name, "vctrs")
}
import_from <- function(name, package) {
  ns <- getNamespace(package)

  if (!exists(name, mode = "function", envir = ns, inherits = FALSE)) {
    abort(sprintf("No such '%s' function: `%s()`.", package, name))
  }

  get(name, mode = "function", envir = ns, inherits = FALSE)
}
