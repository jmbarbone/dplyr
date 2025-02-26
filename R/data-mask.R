DataMask <- R6Class("DataMask",
  public = list(
    initialize = function(data, caller, verb, error_call) {
      rows <- group_rows(data)
      # workaround for when there are 0 groups
      if (length(rows) == 0) {
        rows <- list(integer())
      }
      private$rows <- rows

      frame <- caller_env(n = 2)
      local_mask(self, frame)

      names_bindings <- chr_unserialise_unicode(names2(data))
      if (anyDuplicated(names_bindings)) {
        abort("Can't transform a data frame with duplicate names.", call = error_call)
      }
      names(data) <- names_bindings
      private$data <- data
      private$caller <- caller
      private$current_data <- unclass(data)

      private$chops <- .Call(dplyr_lazy_vec_chop_impl, data, rows)
      private$mask <- .Call(dplyr_data_masks_setup, private$chops, data, rows)

      private$keys <- group_keys(data)
      private$group_vars <- group_vars(data)
      private$verb <- verb
    },

    add_one = function(name, chunks, result) {
      if (inherits(private$data, "rowwise_df")){
        is_scalar_list <- function(.x) {
          vec_is_list(.x) && length(.x) == 1L
        }
        if (all(map_lgl(chunks, is_scalar_list))) {
          chunks <- map(chunks, `[[`, 1L)
        }
      }

      .Call(`dplyr_mask_add`, private, name, result, chunks)
    },

    remove = function(name) {
      .Call(`dplyr_mask_remove`, private, name)
    },

    resolve = function(name) {
      private$chops[[name]]
    },

    eval_all = function(quo) {
      .Call(`dplyr_mask_eval_all`, quo, private)
    },

    eval_all_summarise = function(quo) {
      # Wrap in a function called `eval()` so that rlang ignores the
      # call in error messages. This only concerns errors that occur
      # directly in `quo`.
      eval <- function() .Call(`dplyr_mask_eval_all_summarise`, quo, private)
      eval()
    },

    eval_all_mutate = function(quo) {
      eval <- function() .Call(`dplyr_mask_eval_all_mutate`, quo, private)
      eval()
    },

    eval_all_filter = function(quos, env_filter) {
      eval <- function() .Call(`dplyr_mask_eval_all_filter`, quos, private, nrow(private$data), env_filter)
      eval()
    },

    pick = function(vars) {
      cols <- self$current_cols(vars)
      if (inherits(private$data, "rowwise_df")) {
        cols <- map2(cols, names(cols), function(col, name) {
          if (vec_is_list(private$current_data[[name]])) {
            col <- list(col)
          }
          col
        })
      }
      nrow <- length(self$current_rows())
      new_tibble(cols, nrow = nrow)
    },

    current_cols = function(vars) {
      env_get_list(parent.env(private$mask), vars)
    },

    current_rows = function() {
      private$rows[[self$get_current_group()]]
    },

    current_key = function() {
      vec_slice(private$keys, self$get_current_group())
    },

    current_vars = function() {
      names(private$current_data)
    },

    current_non_group_vars = function() {
      setdiff(self$current_vars(), private$group_vars)
    },

    get_current_group = function() {
      parent.env(private$chops)$.current_group
    },

    set_current_group = function(group) {
      parent.env(private$chops)$.current_group[] <- group
    },

    full_data = function() {
      private$data
    },

    get_used = function() {
      .Call(env_resolved, private$chops, names(private$current_data))
    },

    unused_vars = function() {
      used <- self$get_used()
      current_vars <- self$current_vars()
      current_vars[!used]
    },

    get_rows = function() {
      private$rows
    },

    across_cols = function() {
      private$current_data[self$current_non_group_vars()]
    },

    forget = function() {
      names_bindings <- self$current_vars()
      verb <- private$verb

      osbolete_promise_fn <- function(name) {
        abort(c(
          "Obsolete data mask.",
          x = glue("Too late to resolve `{name}` after the end of `dplyr::{verb}()`."),
          i = glue("Did you save an object that uses `{name}` lazily in a column in the `dplyr::{verb}()` expression ?")
        ), call = NULL)
      }

      promises <- map(names_bindings, function(.x) expr(osbolete_promise_fn(!!.x)))
      bindings <- self$get_env_bindings()
      suppressWarnings({
        rm(list = names_bindings, envir = bindings)
        env_bind_lazy(bindings, !!!set_names(promises, names_bindings))
      })
    },

    get_env_bindings = function() {
      parent.env(private$mask)
    },

    get_rlang_mask = function() {
      private$mask
    },

    get_caller_env = function() {
      private$caller
    }

  ),

  private = list(
    # the input data
    data = NULL,

    # environment that contains lazy vec_chop()s for each input column
    # and list of result chunks as they get added.
    #
    # The parent environment of chops has:
    # - .indices: the list of indices
    # - .current_group: scalar integer that identifies the current group
    chops = NULL,

    # dynamic data mask, with active bindings for each column
    # this is an rlang data mask, as such the bindings are actually
    # in the parent environment of `mask`
    mask = NULL,

    # ptypes of all the variables
    current_data = list(),

    # names of the grouping variables
    group_vars = character(),

    # list of indices, one integer vector per group
    rows = NULL,

    # data frame of keys, one row per group
    keys = NULL,

    # caller environment of the verb (summarise(), ...)
    caller = NULL,

    verb = character()
  )
)
