# Mobile Living 3.10.2

Source base: 23cbaac13f0e326076b2ef2691a2a7d4d970f0cb (3.10.1).
Accepted RC3.9 recovery is unchanged; outgoing 3.10.1 is retained separately.

Both main and F700 seat maps now resolve JoypadIconTextureGetter through the
native ISUITextureGetter helper before reading offsets. Drawing still uses the
original icon, preserving native resolution and adapter draw deduplication.
Shared configuration no longer requires server-only Vehicles/Vehicles; existing
native lifecycle events register callbacks after that module loads. Chassis and
F700 frames retry zero mass while the native physics controller is absent,
without inventing mass or suppressing later invalid-mass diagnostics.

Validation uses installed B42.21.0 native getter classes and seat UI: 74,107 seat
checks, 260,125 bus checks, 175 chassis checks, 88 F700 frame checks and 32,364
cargo assertions. Both adapter load orders pass 1,173 checks. Native Java Texture
resolution, 52 Lua syntax files, 14 manifest tests and 200-key/21-file localization
checks pass. The old seat code fails the native getter regression.

Workshop 3791192579 manifest 2938310983666846217 contains 268 exact files,
runtime SHA256 a19a2b240ad2b9db77834a623a83ee321bced96782fad1445eba7e0db7d56575.
Live description, title, cover, tags and visibility are exactly preserved.
No server restart or manual client deployment was performed. The running local
client still has 3.10.1; its later seat errors at 23:34 and 23:38 are the same
outgoing getOffsetX failure. Publication is not game acceptance. The separately
reported moving roof/vehicle shimmer remains under read-only investigation.
