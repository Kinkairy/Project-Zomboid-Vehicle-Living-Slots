# 3.8.11

Remove the two-model cargo binding and delegate through the original inside-access callback. Keep original seat restrictions; adapt installed VLS beds without enabling outside-only trunks. SUV, PickUpVan, Van and StepVan variants follow the callback actually assigned by their scripts. Seven runtime files change: two cargo integration files, KI5 version, and four mod.info versions. The remaining 221 runtime files are unchanged, including seat-moving and blocked-door guard implementation. Existing cover declarations are preserved.

No server start/stop, installed runtime deployment, source-repository alignment or Workshop action is performed by this commit. Live PZ/Kahlua and multiplayer verification is still required.
