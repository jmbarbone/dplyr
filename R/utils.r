dots <- function(...) {
  eval_bare(substitute(alist(...)))
}

deparse_trunc <- function(x, width = getOption("width")) {
  text <- deparse(x, width.cutoff = width)
  if (length(text) == 1 && nchar(text) < width) return(text)

  paste0(substr(text[1], 1, width - 3), "...")
}

commas <- function(...) paste0(..., collapse = ", ")

is_1d <- function(x) {
  # dimension check is for matrices and data.frames
  (is_atomic(x) || is.list(x)) && length(dim(x)) <= 1
}

unstructure <- function(x) {
  attributes(x) <- NULL
  x
}

compact_null <- function(x) {
  Filter(function(elt) !is.null(elt), x)
}

paste_line <- function(...) {
  paste(chr(...), collapse = "\n")
}

# Until fixed upstream. `vec_data()` should not return lists from data
# frames.
dplyr_vec_data <- function(x) {
  out <- vec_data(x)

  if (is.data.frame(x)) {
    new_data_frame(out, n = nrow(x))
  } else {
    out
  }
}

# Until vctrs::new_data_frame() forwards row names automatically
dplyr_new_data_frame <- function(x = data.frame(),
                                 n = NULL,
                                 ...,
                                 row.names = NULL,
                                 class = NULL) {
  row.names <- row.names %||% .row_names_info(x, type = 0L)

  new_data_frame(
    x,
    n = n,
    ...,
    row.names = row.names,
    class = class
  )
}

# Strips a list-like vector down to just names
dplyr_new_list <- function(x) {
  if (!is_list(x)) {
    abort("`x` must be a VECSXP.", .internal = TRUE)
  }

  names <- names(x)

  if (is.null(names)) {
    attributes(x) <- NULL
  } else {
    attributes(x) <- list(names = names)
  }

  x
}

maybe_restart <- function(restart) {
  if (!is_null(findRestart(restart))) {
    invokeRestart(restart)
  }
}

expr_substitute <- function(expr, old, new) {
  expr <- duplicate(expr)
  switch(typeof(expr),
    language = node_walk_replace(node_cdr(expr), old, new),
    symbol = if (identical(expr, old)) return(new)
  )
  expr
}
node_walk_replace <- function(node, old, new) {
  while (!is_null(node)) {
    switch(typeof(node_car(node)),
      language = if (!is_call(node_car(node), c("~", "function")) || is_call(node_car(node), "~", n = 2)) node_walk_replace(node_cdar(node), old, new),
      symbol = if (identical(node_car(node), old)) node_poke_car(node, new)
    )
    node <- node_cdr(node)
  }
}

# temporary workaround until vctrs better reports error call
fix_call <- function(expr, call = caller_env()) {
  withCallingHandlers(expr, error = function(cnd) {
    cnd$call <- call
    cnd_signal(cnd)
  })
}

# Backports for R 3.5.0 utils
...length2 <- function(frame = caller_env()) {
  length(env_get(frame, "..."))
}
...elt2 <- function(i, frame = caller_env()) {
  eval_bare(sym(paste0("..", i)), frame)
}
