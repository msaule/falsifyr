#' Launch the Attack This Claim RStudio addin
#'
#' Opens a Shiny gadget inside RStudio for selecting a supported model object,
#' choosing a target term, running falsifyr attacks, and viewing the generated
#' report. The result is assigned to `falsifyr_last_attack` in the selected
#' environment.
#'
#' @param envir Environment to scan for supported model objects.
#'
#' @return Invisibly returns `NULL` when the addin cannot be launched; otherwise
#'   launches the gadget for its side effects.
#' @export
attack_this_claim <- function(envir = parent.frame()) {
  if (!requireNamespace("rstudioapi", quietly = TRUE) ||
        !requireNamespace("shiny", quietly = TRUE) ||
        !rstudioapi::isAvailable()) {
    cli::cli_text("The falsifyr addin requires RStudio plus the rstudioapi and shiny packages.")
    return(invisible(NULL))
  }

  models <- addin_supported_models(envir)
  if (!length(models)) {
    cli::cli_text("No supported lm/glm model objects were found in the selected environment.")
    return(invisible(NULL))
  }

  attack_choices <- addin_attack_choices()

  ui <- shiny::fluidPage(
    shiny::tags$head(shiny::tags$style(
      "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:16px;}
       .btn-primary{background:#1f2933;border-color:#1f2933;}
       .form-group{margin-bottom:12px;}"
    )),
    shiny::h3("Attack This Claim"),
    shiny::selectInput("model", "Model object", choices = models),
    shiny::uiOutput("term_ui"),
    shiny::selectInput("intensity", "Intensity", choices = c("normal", "fast", "deep", "insane"), selected = "normal"),
    shiny::checkboxGroupInput("attacks", "Attack families", choices = attack_choices, selected = unname(attack_choices)),
    shiny::actionButton("run", "Attack claim", class = "btn-primary"),
    shiny::hr(),
    shiny::verbatimTextOutput("status")
  )

  server <- function(input, output, session) {
    output$term_ui <- shiny::renderUI({
      terms <- addin_model_terms(get(input$model, envir = envir))
      shiny::selectInput("term", "Claim term", choices = terms)
    })

    output$status <- shiny::renderText("Choose a model and term, then run the attack.")

    shiny::observeEvent(input$run, {
      shiny::req(input$model, input$term)
      model <- get(input$model, envir = envir)
      output$status <- shiny::renderText("Attacking claim...")
      result <- attack(
        model,
        term = input$term,
        attacks = input$attacks,
        intensity = input$intensity,
        seed = 1,
        verbose = FALSE
      )
      assign("falsifyr_last_attack", result, envir = envir)
      file <- tempfile("falsifyr-attack-", fileext = ".html")
      report(result, file = file)
      viewer <- getOption("viewer")
      if (is.function(viewer)) {
        viewer(file)
      } else {
        utils::browseURL(file)
      }
      output$status <- shiny::renderText({
        paste(
          "Done.",
          paste0("Verdict: ", result$verdict, " (", result$survival_score, "/100)."),
          if (is.null(result$smallest_kill)) {
            "Smallest kill: none found."
          } else {
            paste0("Smallest kill: ", result$smallest_kill$explanation)
          },
          "Result assigned to falsifyr_last_attack in the selected environment.",
          sep = "\n"
        )
      })
    })
  }

  viewer <- shiny::dialogViewer("Attack This Claim", width = 620, height = 760)
  shiny::runGadget(ui, server, viewer = viewer)
}

addin_supported_models <- function(envir = parent.frame()) {
  names <- ls(envir = envir, all.names = FALSE)
  supported <- vapply(names, function(name) {
    object <- get(name, envir = envir)
    inherits(object, c("lm", "glm", "aov", "merMod", "coxph"))
  }, logical(1))
  names[supported]
}

addin_model_terms <- function(model) {
  if (!inherits(model, c("lm", "glm", "aov", "merMod", "coxph"))) return(character())
  coefficients <- if (inherits(model, "aov")) {
    lm_model <- model
    class(lm_model) <- "lm"
    summary(lm_model)$coefficients
  } else {
    summary(model)$coefficients
  }
  terms <- rownames(coefficients)
  setdiff(terms, "(Intercept)")
}

addin_attack_choices <- function() {
  c(
    "Row deletion" = "row_deletion",
    "Standard error" = "standard_error",
    "Covariate drop" = "covariate_drop",
    "Missing data" = "missingness",
    "Measurement error" = "measurement_error",
    "Placebo" = "placebo",
    "Specification" = "specification",
    "Split stability" = "split"
  )
}
