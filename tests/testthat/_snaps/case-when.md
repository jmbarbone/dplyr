# `.default` isn't part of recycling

    Code
      case_when(FALSE ~ 1L, .default = 2:5)
    Condition
      Error in `case_when()`:
      ! `.default` must have size 1, not size 4.

# `.default` is part of common type computation

    Code
      case_when(TRUE ~ 1L, .default = "x")
    Condition
      Error in `case_when()`:
      ! Can't combine `1L` <integer> and `.default` <character>.

# passes through `.size` correctly

    Code
      case_when(TRUE ~ 1:2, .size = 3)
    Condition
      Error in `case_when()`:
      ! Can't recycle `1:2` (size 2) to size 3.

# invalid type errors are correct (#6261) (#6206)

    Code
      case_when(TRUE ~ 1, TRUE ~ "x")
    Condition
      Error in `case_when()`:
      ! Can't combine `1` <double> and `"x"` <character>.

# case_when() give meaningful errors

    Code
      (expect_error(case_when(c(TRUE, FALSE) ~ 1:3, c(FALSE, TRUE) ~ 1:2)))
    Output
      <error/vctrs_error_incompatible_size>
      Error in `case_when()`:
      ! Can't recycle `c(TRUE, FALSE)` (size 2) to match `1:3` (size 3).
    Code
      (expect_error(case_when(c(TRUE, FALSE) ~ 1, c(FALSE, TRUE, FALSE) ~ 2, c(FALSE,
        TRUE, FALSE, NA) ~ 3)))
    Output
      <error/vctrs_error_incompatible_size>
      Error in `case_when()`:
      ! Can't recycle `c(TRUE, FALSE)` (size 2) to match `c(FALSE, TRUE, FALSE)` (size 3).
    Code
      (expect_error(case_when(50 ~ 1:3)))
    Output
      <error/vctrs_error_assert_ptype>
      Error in `case_when()`:
      ! `50` must be a vector with type <logical>.
      Instead, it has type <double>.
    Code
      (expect_error(case_when(paste(50))))
    Output
      <error/rlang_error>
      Error in `case_when()`:
      ! Case 1 (`paste(50)`) must be a two-sided formula, not a character vector.
    Code
      (expect_error(case_when(y ~ x, paste(50))))
    Output
      <error/rlang_error>
      Error in `case_when()`:
      ! Case 2 (`paste(50)`) must be a two-sided formula, not a character vector.
    Code
      (expect_error(case_when()))
    Output
      <error/rlang_error>
      Error in `case_when()`:
      ! At least one condition must be supplied.
    Code
      (expect_error(case_when(NULL)))
    Output
      <error/rlang_error>
      Error in `case_when()`:
      ! At least one condition must be supplied.
    Code
      (expect_error(case_when(~ 1:2)))
    Output
      <error/rlang_error>
      Error in `case_when()`:
      ! Case 1 (`~1:2`) must be a two-sided formula.

