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
AnimationSet VLSSolarR3_StepVan_Pose0 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose1 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.017500000,0.0,0.0;;, 30;3;-0.017500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.017500000,0.0,0.0;;, 30;3;0.017500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.008750000,0.0,0.0;;, 30;3;-0.008750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.008750000,0.0,0.0;;, 30;3;0.008750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose2 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.035000000,0.0,0.0;;, 30;3;-0.035000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.035000000,0.0,0.0;;, 30;3;0.035000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.017500000,0.0,0.0;;, 30;3;-0.017500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.017500000,0.0,0.0;;, 30;3;0.017500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose3 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.052500000,0.0,0.0;;, 30;3;-0.052500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.052500000,0.0,0.0;;, 30;3;0.052500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.026250000,0.0,0.0;;, 30;3;-0.026250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.026250000,0.0,0.0;;, 30;3;0.026250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose4 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.070000000,0.0,0.0;;, 30;3;-0.070000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.070000000,0.0,0.0;;, 30;3;0.070000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.035000000,0.0,0.0;;, 30;3;-0.035000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.035000000,0.0,0.0;;, 30;3;0.035000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose5 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.087500000,0.0,0.0;;, 30;3;-0.087500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.087500000,0.0,0.0;;, 30;3;0.087500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.043750000,0.0,0.0;;, 30;3;-0.043750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.043750000,0.0,0.0;;, 30;3;0.043750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose6 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.105000000,0.0,0.0;;, 30;3;-0.105000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.105000000,0.0,0.0;;, 30;3;0.105000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.052500000,0.0,0.0;;, 30;3;-0.052500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.052500000,0.0,0.0;;, 30;3;0.052500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose7 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.122500000,0.0,0.0;;, 30;3;-0.122500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.122500000,0.0,0.0;;, 30;3;0.122500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.061250000,0.0,0.0;;, 30;3;-0.061250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.061250000,0.0,0.0;;, 30;3;0.061250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose8 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.140000000,0.0,0.0;;, 30;3;-0.140000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.140000000,0.0,0.0;;, 30;3;0.140000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.070000000,0.0,0.0;;, 30;3;-0.070000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.070000000,0.0,0.0;;, 30;3;0.070000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose9 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.157500000,0.0,0.0;;, 30;3;-0.157500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.157500000,0.0,0.0;;, 30;3;0.157500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.078750000,0.0,0.0;;, 30;3;-0.078750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.078750000,0.0,0.0;;, 30;3;0.078750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose10 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.175000000,0.0,0.0;;, 30;3;-0.175000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.175000000,0.0,0.0;;, 30;3;0.175000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.087500000,0.0,0.0;;, 30;3;-0.087500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.087500000,0.0,0.0;;, 30;3;0.087500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose11 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.192500000,0.0,0.0;;, 30;3;-0.192500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.192500000,0.0,0.0;;, 30;3;0.192500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.096250000,0.0,0.0;;, 30;3;-0.096250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.096250000,0.0,0.0;;, 30;3;0.096250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose12 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.210000000,0.0,0.0;;, 30;3;-0.210000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.210000000,0.0,0.0;;, 30;3;0.210000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.105000000,0.0,0.0;;, 30;3;-0.105000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.105000000,0.0,0.0;;, 30;3;0.105000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose13 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.227500000,0.0,0.0;;, 30;3;-0.227500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.227500000,0.0,0.0;;, 30;3;0.227500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.113750000,0.0,0.0;;, 30;3;-0.113750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.113750000,0.0,0.0;;, 30;3;0.113750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose14 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.245000000,0.0,0.0;;, 30;3;-0.245000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.245000000,0.0,0.0;;, 30;3;0.245000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.122500000,0.0,0.0;;, 30;3;-0.122500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.122500000,0.0,0.0;;, 30;3;0.122500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose15 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.262500000,0.0,0.0;;, 30;3;-0.262500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.262500000,0.0,0.0;;, 30;3;0.262500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.131250000,0.0,0.0;;, 30;3;-0.131250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.131250000,0.0,0.0;;, 30;3;0.131250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose16 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.280000000,0.0,0.0;;, 30;3;-0.280000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.280000000,0.0,0.0;;, 30;3;0.280000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.140000000,0.0,0.0;;, 30;3;-0.140000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.140000000,0.0,0.0;;, 30;3;0.140000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose17 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.297500000,0.0,0.0;;, 30;3;-0.297500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.297500000,0.0,0.0;;, 30;3;0.297500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.148750000,0.0,0.0;;, 30;3;-0.148750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.148750000,0.0,0.0;;, 30;3;0.148750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose18 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.315000000,0.0,0.0;;, 30;3;-0.315000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.315000000,0.0,0.0;;, 30;3;0.315000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.157500000,0.0,0.0;;, 30;3;-0.157500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.157500000,0.0,0.0;;, 30;3;0.157500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose19 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.332500000,0.0,0.0;;, 30;3;-0.332500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.332500000,0.0,0.0;;, 30;3;0.332500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.166250000,0.0,0.0;;, 30;3;-0.166250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.166250000,0.0,0.0;;, 30;3;0.166250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose20 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.350000000,0.0,0.0;;, 30;3;-0.350000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.350000000,0.0,0.0;;, 30;3;0.350000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.175000000,0.0,0.0;;, 30;3;-0.175000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.175000000,0.0,0.0;;, 30;3;0.175000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose21 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.367500000,0.0,0.0;;, 30;3;-0.367500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.367500000,0.0,0.0;;, 30;3;0.367500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.183750000,0.0,0.0;;, 30;3;-0.183750000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.183750000,0.0,0.0;;, 30;3;0.183750000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose22 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.385000000,0.0,0.0;;, 30;3;-0.385000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.385000000,0.0,0.0;;, 30;3;0.385000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.192500000,0.0,0.0;;, 30;3;-0.192500000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.192500000,0.0,0.0;;, 30;3;0.192500000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose23 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.402500000,0.0,0.0;;, 30;3;-0.402500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.402500000,0.0,0.0;;, 30;3;0.402500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.201250000,0.0,0.0;;, 30;3;-0.201250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.201250000,0.0,0.0;;, 30;3;0.201250000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_StepVan_Pose24 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.420000000,0.0,0.0;;, 30;3;-0.420000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.420000000,0.0,0.0;;, 30;3;0.420000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.210000000,0.0,0.0;;, 30;3;-0.210000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.210000000,0.0,0.0;;, 30;3;0.210000000,0.0,0.0;;; } }
}
