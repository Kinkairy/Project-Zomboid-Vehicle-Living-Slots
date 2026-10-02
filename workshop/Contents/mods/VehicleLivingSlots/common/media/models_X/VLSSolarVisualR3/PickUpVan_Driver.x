xof 0303txt 0032
Frame VLSSceneRoot { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
Frame VehicleSkeleton { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
Frame SolarLeft { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; } }
Frame SolarRight { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; } }
Frame SolarMiddleLeft { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; } }
Frame SolarMiddleRight { FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; } }
Mesh VLSSolarR3Driver {
6;
0.000000000;0.000000000;0.000000000;,
-0.001000000;0.000000000;0.000000000;,
0.001000000;0.000000000;0.000000000;,
0.000000000;0.000000000;0.000000000;,
-0.002000000;0.000000000;0.000000000;,
0.002000000;0.000000000;0.000000000;;
2;
3;0,1,2;,
3;3,4,5;;
MeshNormals {
6;
0.000000000;1.000000000;0.000000000;,
0.000000000;1.000000000;0.000000000;,
0.000000000;1.000000000;0.000000000;,
0.000000000;1.000000000;0.000000000;,
0.000000000;1.000000000;0.000000000;,
0.000000000;1.000000000;0.000000000;;
2;
3;0,1,2;,
3;3,4,5;;
}
MeshTextureCoords {
6;
0.800000000;0.500000000;,
0.800000000;0.500000000;,
0.800000000;0.500000000;,
0.800000000;0.500000000;,
0.800000000;0.500000000;,
0.800000000;0.500000000;;
}
XSkinMeshHeader { 1; 3; 5; }
SkinWeights { "VehicleSkeleton"; 2; 0,3; 1.0,1.0; 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
SkinWeights { "SolarLeft"; 1; 1; 1.0; 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
SkinWeights { "SolarRight"; 1; 2; 1.0; 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
SkinWeights { "SolarMiddleLeft"; 1; 4; 1.0; 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
SkinWeights { "SolarMiddleRight"; 1; 5; 1.0; 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }
}
}
}
AnimTicksPerSecond { 30; }
AnimationSet VLSSolarR3_PickUpVan_Pose0 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose1 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.011562500,0.0,0.0;;, 30;3;-0.011562500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.011562500,0.0,0.0;;, 30;3;0.011562500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.005781250,0.0,0.0;;, 30;3;-0.005781250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.005781250,0.0,0.0;;, 30;3;0.005781250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose2 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.023125000,0.0,0.0;;, 30;3;-0.023125000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.023125000,0.0,0.0;;, 30;3;0.023125000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.011562500,0.0,0.0;;, 30;3;-0.011562500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.011562500,0.0,0.0;;, 30;3;0.011562500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose3 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.034687500,0.0,0.0;;, 30;3;-0.034687500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.034687500,0.0,0.0;;, 30;3;0.034687500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.017343750,0.0,0.0;;, 30;3;-0.017343750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.017343750,0.0,0.0;;, 30;3;0.017343750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose4 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.046250000,0.0,0.0;;, 30;3;-0.046250000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.046250000,0.0,0.0;;, 30;3;0.046250000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.023125000,0.0,0.0;;, 30;3;-0.023125000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.023125000,0.0,0.0;;, 30;3;0.023125000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose5 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.057812500,0.0,0.0;;, 30;3;-0.057812500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.057812500,0.0,0.0;;, 30;3;0.057812500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.028906250,0.0,0.0;;, 30;3;-0.028906250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.028906250,0.0,0.0;;, 30;3;0.028906250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose6 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.069375000,0.0,0.0;;, 30;3;-0.069375000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.069375000,0.0,0.0;;, 30;3;0.069375000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.034687500,0.0,0.0;;, 30;3;-0.034687500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.034687500,0.0,0.0;;, 30;3;0.034687500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose7 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.080937500,0.0,0.0;;, 30;3;-0.080937500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.080937500,0.0,0.0;;, 30;3;0.080937500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.040468750,0.0,0.0;;, 30;3;-0.040468750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.040468750,0.0,0.0;;, 30;3;0.040468750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose8 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.092500000,0.0,0.0;;, 30;3;-0.092500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.092500000,0.0,0.0;;, 30;3;0.092500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.046250000,0.0,0.0;;, 30;3;-0.046250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.046250000,0.0,0.0;;, 30;3;0.046250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose9 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.104062500,0.0,0.0;;, 30;3;-0.104062500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.104062500,0.0,0.0;;, 30;3;0.104062500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.052031250,0.0,0.0;;, 30;3;-0.052031250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.052031250,0.0,0.0;;, 30;3;0.052031250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose10 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.115625000,0.0,0.0;;, 30;3;-0.115625000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.115625000,0.0,0.0;;, 30;3;0.115625000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.057812500,0.0,0.0;;, 30;3;-0.057812500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.057812500,0.0,0.0;;, 30;3;0.057812500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose11 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.127187500,0.0,0.0;;, 30;3;-0.127187500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.127187500,0.0,0.0;;, 30;3;0.127187500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.063593750,0.0,0.0;;, 30;3;-0.063593750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.063593750,0.0,0.0;;, 30;3;0.063593750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose12 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.138750000,0.0,0.0;;, 30;3;-0.138750000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.138750000,0.0,0.0;;, 30;3;0.138750000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.069375000,0.0,0.0;;, 30;3;-0.069375000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.069375000,0.0,0.0;;, 30;3;0.069375000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose13 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.150312500,0.0,0.0;;, 30;3;-0.150312500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.150312500,0.0,0.0;;, 30;3;0.150312500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.075156250,0.0,0.0;;, 30;3;-0.075156250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.075156250,0.0,0.0;;, 30;3;0.075156250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose14 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.161875000,0.0,0.0;;, 30;3;-0.161875000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.161875000,0.0,0.0;;, 30;3;0.161875000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.080937500,0.0,0.0;;, 30;3;-0.080937500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.080937500,0.0,0.0;;, 30;3;0.080937500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose15 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.173437500,0.0,0.0;;, 30;3;-0.173437500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.173437500,0.0,0.0;;, 30;3;0.173437500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.086718750,0.0,0.0;;, 30;3;-0.086718750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.086718750,0.0,0.0;;, 30;3;0.086718750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose16 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.185000000,0.0,0.0;;, 30;3;-0.185000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.185000000,0.0,0.0;;, 30;3;0.185000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.092500000,0.0,0.0;;, 30;3;-0.092500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.092500000,0.0,0.0;;, 30;3;0.092500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose17 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.196562500,0.0,0.0;;, 30;3;-0.196562500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.196562500,0.0,0.0;;, 30;3;0.196562500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.098281250,0.0,0.0;;, 30;3;-0.098281250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.098281250,0.0,0.0;;, 30;3;0.098281250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose18 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.208125000,0.0,0.0;;, 30;3;-0.208125000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.208125000,0.0,0.0;;, 30;3;0.208125000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.104062500,0.0,0.0;;, 30;3;-0.104062500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.104062500,0.0,0.0;;, 30;3;0.104062500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose19 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.219687500,0.0,0.0;;, 30;3;-0.219687500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.219687500,0.0,0.0;;, 30;3;0.219687500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.109843750,0.0,0.0;;, 30;3;-0.109843750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.109843750,0.0,0.0;;, 30;3;0.109843750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose20 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.231250000,0.0,0.0;;, 30;3;-0.231250000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.231250000,0.0,0.0;;, 30;3;0.231250000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.115625000,0.0,0.0;;, 30;3;-0.115625000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.115625000,0.0,0.0;;, 30;3;0.115625000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose21 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.242812500,0.0,0.0;;, 30;3;-0.242812500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.242812500,0.0,0.0;;, 30;3;0.242812500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.121406250,0.0,0.0;;, 30;3;-0.121406250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.121406250,0.0,0.0;;, 30;3;0.121406250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose22 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.254375000,0.0,0.0;;, 30;3;-0.254375000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.254375000,0.0,0.0;;, 30;3;0.254375000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.127187500,0.0,0.0;;, 30;3;-0.127187500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.127187500,0.0,0.0;;, 30;3;0.127187500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose23 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.265937500,0.0,0.0;;, 30;3;-0.265937500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.265937500,0.0,0.0;;, 30;3;0.265937500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.132968750,0.0,0.0;;, 30;3;-0.132968750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.132968750,0.0,0.0;;, 30;3;0.132968750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_PickUpVan_Pose24 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.277500000,0.0,0.0;;, 30;3;-0.277500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.277500000,0.0,0.0;;, 30;3;0.277500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.138750000,0.0,0.0;;, 30;3;-0.138750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.138750000,0.0,0.0;;, 30;3;0.138750000,0.0,0.0;;; } }
}
