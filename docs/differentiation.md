# Differentiation

Working sentence:

> Existing tools help define, diagnose, or run robustness analyses. `falsifyr`
> automatically attacks a fitted claim and searches for the smallest plausible
> perturbation that changes the conclusion.

`falsifyr` is not trying to become a general diagnostics package, a multiverse
authoring framework, or a p-hacking detector. It is an adversarial robustness
engine for fitted results. The user gives it one model and one term; it attacks
that claim and reports the smallest kill.

## Adjacent tools

| Tool | What it does | Why `falsifyr` is different |
|---|---|---|
| `specr` | Specification curve and multiverse analysis tooling for defining, running, evaluating, and plotting many specifications. | The analyst defines the specification grid. `falsifyr` starts from a fitted object and searches for the smallest claim kill. |
| `multiverse` | Lets users declare alternative analysis branches and execute multiverse-style analyses. | Powerful, but user-authored. `falsifyr` is model-first and adversarial by default. |
| `sensemakr` | Sensitivity analysis for omitted-variable bias in regression models. | Deep and important, but focused on one sensitivity family. `falsifyr` orchestrates row, uncertainty, missingness, noise, placebo, and specification attacks around one claim. |
| `tipr` | Tipping-point analysis around unmeasured confounding and how a result may tip to insignificance. | Philosophically close. `falsifyr` generalizes the tipping-point idea across many perturbation families and reports an attack leaderboard. |
| `influence.ME` | Detects influential cases in generalized mixed-effects models, including changes in significance when units are removed. | Strong precedent for influence attacks, but one family and model area. `falsifyr` makes influence one part of a smallest-kill claim survival engine. |
| `performance` | Model-quality assessment and diagnostic checks across many regression models. | Diagnostics are not adversarial search. `falsifyr` asks what kills a named claim. |
| `sandwich` | Robust covariance matrix estimators. | `falsifyr` may call robust SE tools, but its value is interpreting whether robust uncertainty kills the claim. |
| `lmtest` | Tests for linear regression models and coefficient tests. | Useful infrastructure, not a claim attack engine. |
| `robustbase` | Robust statistical methods and robust model fitting. | Robust estimation is one possible attack surface; it is not smallest-kill orchestration. |
| `causalfrag` | A close 2026 CRAN neighbor. It provides a cross-framework causal fragility index for unmeasured-confounding sensitivity analyses, combining robustness values, E-values, and ITCV-style evidence into a 0-100 score with narrative/reporting support. | `falsifyr` must stay broader and more adversarial: fitted-object-first, term-first, multi-family perturbation attacks, smallest-kill reporting, and RStudio/HTML survival cards. It should not collapse into one causal confounding score. |
| `fragilityindex` | Calculates clinical-trial fragility indices by finding how many outcome changes make a significant result non-significant. | Very close to the "what kills significance?" spirit, but focused on contingency/trial outcome flips. `falsifyr` generalizes the kill-distance idea to ordinary fitted claims and multiple perturbation families. |

## Research notes

- 2026-07-08: `causalfrag` 0.1.1 is a particularly close current package. Its CRAN description frames the package around unmeasured-confounding sensitivity frameworks and a single Causal Fragility Index. This confirms that `falsifyr` should avoid becoming a generic fragility score and should instead emphasize smallest-kill search across row deletion, uncertainty, missing data, measurement error, placebo labels, and bounded specification attacks.
- 2026-07-08: `fragilityindex` is a useful conceptual precedent for kill-distance language, but its clinical-trial outcome-flip focus leaves room for `falsifyr`'s fitted-model claim attack workflow.

## Product boundary

Features should be cut or repositioned when they drift toward generic
diagnostics. The question every feature must answer is:

> Does this help find or explain the smallest plausible attack that kills the
> named claim?

If not, it probably does not belong in the core package.
