# Refit a model on perturbed data

Refits a supported model class with a replacement data frame and
optional formula. Attack families use this generic internally, and it is
exported for users who want reproducible perturbation workflows. For
`lm` and `glm` model frames, evaluated weights and offsets are preserved
where possible.

## Usage

``` r
refit_model(model, data, formula = NULL, ...)

# S3 method for class 'lm'
refit_model(model, data, formula = NULL, ...)

# S3 method for class 'glm'
refit_model(model, data, formula = NULL, ...)

# S3 method for class 'aov'
refit_model(model, data, formula = NULL, ...)

# S3 method for class 'merMod'
refit_model(model, data, formula = NULL, ...)

# S3 method for class 'coxph'
refit_model(model, data, formula = NULL, ...)
```

## Arguments

- model:

  A fitted model object.

- data:

  A data frame for the refit.

- formula:

  Optional replacement formula. Defaults to the model formula.

- ...:

  Additional arguments passed to the model-fitting function.

## Value

A refitted model object of the same broad class as `model`.

## Examples

``` r
fit <- lm(score ~ treatment + age, data = fragile_trial)
refit_model(fit, data = fragile_trial)
#> 
#> Call:
#> (function (formula, data, subset, weights, na.action, method = "qr", 
#>     model = TRUE, x = FALSE, y = FALSE, qr = TRUE, singular.ok = TRUE, 
#>     contrasts = NULL, offset, ...) 
#> {
#>     ret.x <- x
#>     ret.y <- y
#>     cl <- match.call()
#>     mf <- match.call(expand.dots = FALSE)
#>     m <- match(c("formula", "data", "subset", "weights", "na.action", 
#>         "offset"), names(mf), 0L)
#>     mf <- mf[c(1L, m)]
#>     mf$drop.unused.levels <- TRUE
#>     mf[[1L]] <- quote(stats::model.frame)
#>     mf <- eval(mf, parent.frame())
#>     if (method == "model.frame") 
#>         return(mf)
#>     else if (method != "qr") 
#>         warning(gettextf("method = '%s' is not supported. Using 'qr'", 
#>             method), domain = NA)
#>     mt <- attr(mf, "terms")
#>     y <- model.response(mf, "numeric")
#>     w <- as.vector(model.weights(mf))
#>     if (!is.null(w) && !is.numeric(w)) 
#>         stop("'weights' must be a numeric vector")
#>     offset <- model.offset(mf)
#>     mlm <- is.matrix(y)
#>     ny <- if (mlm) 
#>         nrow(y)
#>     else length(y)
#>     if (!is.null(offset)) {
#>         if (!mlm) 
#>             offset <- as.vector(offset)
#>         if (NROW(offset) != ny) 
#>             stop(gettextf("number of offsets is %d, should equal %d (number of observations)", 
#>                 NROW(offset), ny), domain = NA)
#>     }
#>     if (is.empty.model(mt)) {
#>         x <- NULL
#>         z <- list(coefficients = if (mlm) matrix(NA_real_, 0, 
#>             ncol(y)) else numeric(), residuals = y, fitted.values = 0 * 
#>             y, weights = w, rank = 0L, df.residual = if (!is.null(w)) sum(w != 
#>             0) else ny)
#>         if (!is.null(offset)) {
#>             z$fitted.values <- offset
#>             z$residuals <- y - offset
#>         }
#>     }
#>     else {
#>         x <- model.matrix(mt, mf, contrasts)
#>         z <- if (is.null(w)) 
#>             lm.fit(x, y, offset = offset, singular.ok = singular.ok, 
#>                 ...)
#>         else lm.wfit(x, y, w, offset = offset, singular.ok = singular.ok, 
#>             ...)
#>     }
#>     class(z) <- c(if (mlm) "mlm", "lm")
#>     z$na.action <- attr(mf, "na.action")
#>     z$offset <- offset
#>     z$contrasts <- attr(x, "contrasts")
#>     z$xlevels <- .getXlevels(mt, mf)
#>     z$call <- cl
#>     z$terms <- mt
#>     if (model) 
#>         z$model <- mf
#>     if (ret.x) 
#>         z$x <- x
#>     if (ret.y) 
#>         z$y <- y
#>     if (!qr) 
#>         z$qr <- NULL
#>     z
#> })(formula = score ~ treatment + age, data = structure(list(score = c(1.15704352829782, 
#> -0.721647479718112, 0.219197857836128, 0.0423884206498975, -1.48821347091762, 
#> 0.666977926187571, 1.83379406107003, -1.22252577286051, -0.403006795636431, 
#> 1.40683755583876, 2.07667228059134, 1.98640892073626, -0.0299788956897253, 
#> 0.031602774281763, -0.679203358317666, -0.783035090993729, 1.27486970624481, 
#> -0.197556488219532, 0.836694070560297, -0.94871642741351, 0.42070398077556, 
#> -0.449177958188279, 0.812716078344996, -0.485912239207674, 0.520119114647509, 
#> 2.05407483742274, 0.991885461855297, 1.73025907943093, -0.100200427595475, 
#> 0.749856002704138, -0.846410685885338, 0.359688027701876, -0.186652772006937, 
#> 0.881784749264512, 1.48954811747224, 1.17061688727795, 0.551859512379112, 
#> 0.334821607061309, -0.154612663913491, -0.432306756621425, 3.04202763748588, 
#> 1.39782214068279, 5.14295728238564, 2.46024406992807, -0.63481905869302, 
#> 1.22978942227801, 0.0772642522936567, 0.514551845997066, 0.153802290326342, 
#> -0.230637977979146, 1.50009652558823, 0.46559679219828, 2.1791351506365, 
#> -1.35295781630985, 1.04967522442657, 1.17882040975403, 1.8455113401212, 
#> -0.0494762282671616, 0.704812249201394, 1.27252199672208, 0.356212924640616, 
#> 1.42101514342912, -0.528038087580618, 2.00138643375741, 0.938639415623425, 
#> 0.47780714963595, 0.528308621932862, 1.36807287941199, -0.133310619788268, 
#> 1.6548680546341, 2.02897712245307, -1.01198172968843, 0.350494475396868, 
#> 0.137550830425466, -0.226461658179528, -0.984492346666122, 0.546406438436621, 
#> 1.15092695250066, 0.802539894426231, 0.2195053659994), treatment = c(0, 
#> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
#> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 
#> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
#> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1), age = c(41, 
#> 52, 66, 39, 49, 51, 57, 48, 70, 49, 54, 60, 46, 40, 68, 27, 59, 
#> 50, 60, 54, 71, 38, 66, 70, 50, 25, 55, 44, 58, 53, 57, 53, 61, 
#> 47, 42, 44, 33, 41, 44, 48, 46, 30, 42, 69, 56, 70, 47, 49, 48, 
#> 38, 42, 71, 44, 63, 40, 30, 47, 59, 61, 67, 32, 70, 43, 52, 55, 
#> 42, 30, 45, 51, 41, 41, 53, 49, 54, 49, 41, 63, 58, 61, 36), 
#>     baseline_score = c(0.995984589777751, -1.69576490337902, 
#>     -0.533372142547197, -1.37226945114308, -2.20791977880464, 
#>     1.82212251875356, -0.653393410818779, -0.284681219355068, 
#>     -0.386949603644931, 0.386694974646073, 1.60039085153952, 
#>     1.68115495576682, -1.18360638822726, -1.3584572535632, -1.512670794721, 
#>     -1.2531048993692, 1.9593570771456, 0.00764587213276751, -0.842615197589633, 
#>     -0.601160105152349, 1.07445940641284, 0.260597835092159, 
#>     -0.31427198017192, -0.749630095483078, -0.862198329685807, 
#>     2.04804030304848, 0.939920077613375, 2.00868711591535, -0.421373572405353, 
#>     -0.350834423147859, -1.02738059808676, -0.250519126720292, 
#>     0.471859466116943, 1.35893982099811, 0.564168602683639, 0.455980090481221, 
#>     1.23095366302092, 1.14713684772712, 0.106598040927417, -0.783316657008623, 
#>     1.24119982707737, 0.138858419103515, 1.71063158823657, -0.430640974722993, 
#>     NA, NA, NA, NA, NA, NA, 0.689804173282994, 0.330963177173467, 
#>     0.871067708948055, -2.01624558221344, 1.21257910351036, 1.20049469882194, 
#>     1.03206832593544, 0.786410256177216, 2.11007351377927, -1.45380984681329, 
#>     -0.58310384813065, 0.409723982550305, -0.806981635414238, 
#>     0.0855504408545073, 0.746243168639741, -0.653673061331084, 
#>     0.657105983301959, 0.549909235009709, -0.806729358432671, 
#>     -0.997379717276235, 0.97589063842626, -0.169423180700716, 
#>     0.72219177943747, -0.844418606912503, 1.27729368500115, -1.34311054918022, 
#>     0.765340668860696, 0.464202569980373, 0.267993278040529, 
#>     0.667522687135242)), class = "data.frame", row.names = c(NA, 
#> -80L)))
#> 
#> Coefficients:
#> (Intercept)    treatment          age  
#>    0.752262     0.453820    -0.007656  
#> 
```
