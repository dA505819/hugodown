server_start <- function(path, auto_navigate = TRUE) {
  server_stop()

  port <- 1313L
  args <- c(
    "server",
    "--port", port,
    if (auto_navigate) "--navigateToChanged"
  )

  message("Starting server on port ", port)
  ps <- processx::process$new(
    hugo_locate(),
    args,
    wd = path,
    stdout = "|",
    stderr = "2>&1",
  )
  if (!ps$is_alive()) {
    abort(ps$read_error())
  }

  # Swallow initial text
  init <- ""
  repeat {
    ps$poll_io(250)
    init <- paste0(init, ps$read_output())

    if (grepl("already in use", init, fixed = TRUE)) {
      ps$kill()
      abort("Port already in use")
    }

    if (grepl("Ctrl+C", init, fixed = TRUE)) {
      break
    }
  }

  # Ensure output pipe doesn't get swamped
  poll_process <- function() {
    if (!ps$is_alive()) {
      return()
    }

    out <- ps$read_output()
    if (!identical(out, "")) {
      cat(out)
    }

    later::later(delay = 1, poll_process)
  }
  poll_process()

  hugodown$server <- ps
  invisible(ps)
}

server_view <- function() {
  if (rstudioapi::hasFun("viewer")) {
    rstudioapi::viewer("http://localhost:1313")
  } else {
    utils::browseURL("http://localhost:1313")
  }
}

server_running <- function() {
  env_has(hugodown, "server") && hugodown$server$is_alive()
}

server_stop <- function() {
  if (!server_running()) {
    return(invisible())
  }

  hugodown$server$interrupt()
  hugodown$server$poll_io(500)
  hugodown$server$kill()
  env_unbind(hugodown, "server")
  invisible()
}