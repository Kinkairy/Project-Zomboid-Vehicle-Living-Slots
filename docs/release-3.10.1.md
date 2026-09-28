# Mobile Living 3.10.1

Fixes repeated `expected argument of type Texture, got Double` errors when
opening the mechanics window for KI5 Campers, F700 vehicles and B700 buses.
Both optional overlays now pass the explicit texture and line-width arguments
required by the installed B42.21.0 `ISUIElement:drawLine` interface.
Connector positions, color, opacity, hit regions and vehicle behavior are unchanged.
The F700 optional module advances from 0.1.0 to 0.1.1 and requires VLS 3.10.1.

The regression suite loads the installed native drawLine and texture resolver,
checks its Java-boundary argument types, and verifies hook restoration after
line-drawing failures. Both addon load orders fail with the outgoing code and
pass with the fix across 11 models and 42 component regions under Lua 5.1.
A separate probe using the installed game Kahlua, native number converter and
real Java UIElement reproduces the outgoing Texture type error and successfully
executes the corrected DrawLine call. Pixel geometry is
checked against the unchanged native KI5 artwork. These are native-interface
and offline checks, not owner in-game acceptance.

The issue is confirmed on B42.21.0. No claim is made that the API first changed
in 42.21. Source base: cf47fea4a3e1eb67b215075026634bc7955c71a2 (3.10).
The accepted RC3.9 rollback remains unchanged; outgoing 3.10 is retained separately.
No server restart or manual client deployment is part of this publication.
