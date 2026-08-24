# Fish-style history autosuggestions via PSReadLine (bundled with PowerShell
# 7, no separate install needed — verified live on winlab.local, PSReadLine
# 2.4.5). Guarded on IsOutputRedirected: verified live that calling
# Set-PSReadLineOption in a context without a real console (e.g. a script
# dot-sourcing $PROFILE with redirected output) throws "the predictive
# suggestion feature cannot be enabled" — this is expected there, not a bug,
# but must not break the rest of the profile loading.
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
