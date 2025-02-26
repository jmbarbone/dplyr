#' Set operations
#'
#' These functions override the set functions provided in base to make them
#' generic so that efficient versions for data frames and other tables can be
#' provided. The default methods call the base versions. Beware that
#' `intersect()`, `union()` and `setdiff()` remove duplicates.
#'
#' @param x,y objects to perform set function on (ignoring order)
#' @inheritParams rlang::args_dots_empty
#' @name setops
#' @examples
#' mtcars$model <- rownames(mtcars)
#' first <- mtcars[1:20, ]
#' second <- mtcars[10:32, ]
#'
#' intersect(first, second)
#' union(first, second)
#' setdiff(first, second)
#' setdiff(second, first)
#'
#' union_all(first, second)
#' setequal(mtcars, mtcars[32:1, ])
#'
#' # Handling of duplicates:
#' a <- data.frame(column = c(1:10, 10))
#' b <- data.frame(column = c(1:5, 5))
#'
#' # intersection is 1 to 5, duplicates removed (5)
#' intersect(a, b)
#'
#' # union is 1 to 10, duplicates removed (5 and 10)
#' union(a, b)
#'
#' # set difference, duplicates removed (10)
#' setdiff(a, b)
#'
#' # union all does not remove duplicates
#' union_all(a, b)
NULL

#' @rdname setops
#' @export
union_all <- function(x, y, ...) UseMethod("union_all")
#' @export
union_all.default <- function (x, y, ...) {
  check_dots_empty()
  vec_c(x, y)
}

#' @importFrom generics intersect
#' @export
generics::intersect

#' @importFrom generics union
#' @export
generics::union

#' @importFrom generics setdiff
#' @export
generics::setdiff

#' @importFrom generics setequal
#' @export
generics::setequal

#' @export
intersect.data.frame <- function(x, y, ...) {
  check_dots_empty()
  check_compatible(x, y)

  cast <- vec_cast_common(x = x, y = y)
  out <- vec_unique(vec_slice(cast$x, vec_in(cast$x, cast$y)))
  dplyr_reconstruct(out, x)
}

#' @export
union.data.frame <- function(x, y, ...) {
  check_dots_empty()
  check_compatible(x, y)

  out <- vec_unique(vec_rbind(x, y))
  dplyr_reconstruct(out, x)
}

#' @export
union_all.data.frame <- function(x, y, ...) {
  check_dots_empty()
  check_compatible(x, y)

  out <- vec_rbind(x, y)
  dplyr_reconstruct(out, x)
}

#' @export
setdiff.data.frame <- function(x, y, ...) {
  check_dots_empty()
  check_compatible(x, y)

  cast <- vec_cast_common(x = x, y = y)
  out <- vec_unique(vec_slice(cast$x, !vec_in(cast$x, cast$y)))
  dplyr_reconstruct(out, x)
}

#' @export
setequal.data.frame <- function(x, y, ...) {
  check_dots_empty()
  if (!is.data.frame(y)) {
    abort("`y` must be a data frame.")
  }
  if (!isTRUE(is_compatible(x, y))) {
    return(FALSE)
  }

  cast <- vec_cast_common(x = x, y = y)
  all(vec_in(cast$x, cast$y)) && all(vec_in(cast$y, cast$x))
}


# Helpers -----------------------------------------------------------------

is_compatible <- function(x, y, ignore_col_order = TRUE, convert = TRUE) {
  if (!is.data.frame(y)) {
    return("`y` must be a data frame.")
  }

  nc <- ncol(x)
  if (nc != ncol(y)) {
    return(
      c(x = glue("Different number of columns: {nc} vs {ncol(y)}."))
    )
  }

  names_x <- names(x)
  names_y <- names(y)

  names_y_not_in_x <- setdiff(names_y, names_x)
  names_x_not_in_y <- setdiff(names_x, names_y)

  if (length(names_y_not_in_x) == 0L && length(names_x_not_in_y) == 0L) {
    # check if same order
    if (!isTRUE(ignore_col_order)) {
      if (!identical(names_x, names_y)) {
        return(c(x = "Same column names, but different order."))
      }
    }
  } else {
    # names are not the same, explain why

    msg <- c()
    if (length(names_y_not_in_x)) {
      wrong <- glue_collapse(glue('`{names_y_not_in_x}`'), sep = ", ")
      msg <- c(
        msg,
        x = glue("Cols in `y` but not `x`: {wrong}.")
      )
    }
    if (length(names_x_not_in_y)) {
      wrong <- glue_collapse(glue('`{names_x_not_in_y}`'), sep = ", ")
      msg <- c(
        msg,
        x = glue("Cols in `x` but not `y`: {wrong}.")
      )
    }
    return(msg)
  }

  msg <- c()
  for (name in names_x) {
    x_i <- x[[name]]
    y_i <- y[[name]]

    if (convert) {
      tryCatch(
        vec_ptype2(x_i, y_i),
        error = function(e) {
          msg <<- c(
            msg,
            x = glue("Incompatible types for column `{name}`: {vec_ptype_full(x_i)} vs {vec_ptype_full(y_i)}.")
          )
        }
      )
    } else {
      if (!identical(vec_ptype(x_i), vec_ptype(y_i))) {
        msg <- c(
          msg,
          x = glue("Different types for column `{name}`: {vec_ptype_full(x_i)} vs {vec_ptype_full(y_i)}.")
        )
      }
    }
  }
  if (length(msg)) {
    return(msg)
  }

  TRUE
}

check_compatible <- function(x, y, ignore_col_order = TRUE, convert = TRUE, error_call = caller_env()) {
  compat <- is_compatible(x, y, ignore_col_order = ignore_col_order, convert = convert)
  if (isTRUE(compat)) {
    return()
  }

  abort(c("`x` and `y` are not compatible.", compat), call = error_call)
}
