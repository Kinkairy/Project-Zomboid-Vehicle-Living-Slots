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
AnimationSet VLSSolarR3_Van_Pose0 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose1 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.015104167,0.0,0.0;;, 30;3;-0.015104167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.015104167,0.0,0.0;;, 30;3;0.015104167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.007552083,0.0,0.0;;, 30;3;-0.007552083,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.007552083,0.0,0.0;;, 30;3;0.007552083,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose2 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.030208333,0.0,0.0;;, 30;3;-0.030208333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.030208333,0.0,0.0;;, 30;3;0.030208333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.015104167,0.0,0.0;;, 30;3;-0.015104167,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.015104167,0.0,0.0;;, 30;3;0.015104167,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose3 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.045312500,0.0,0.0;;, 30;3;-0.045312500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.045312500,0.0,0.0;;, 30;3;0.045312500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.022656250,0.0,0.0;;, 30;3;-0.022656250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.022656250,0.0,0.0;;, 30;3;0.022656250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose4 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.060416667,0.0,0.0;;, 30;3;-0.060416667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.060416667,0.0,0.0;;, 30;3;0.060416667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.030208333,0.0,0.0;;, 30;3;-0.030208333,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.030208333,0.0,0.0;;, 30;3;0.030208333,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose5 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.075520833,0.0,0.0;;, 30;3;-0.075520833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.075520833,0.0,0.0;;, 30;3;0.075520833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.037760417,0.0,0.0;;, 30;3;-0.037760417,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.037760417,0.0,0.0;;, 30;3;0.037760417,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose6 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.090625000,0.0,0.0;;, 30;3;-0.090625000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.090625000,0.0,0.0;;, 30;3;0.090625000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.045312500,0.0,0.0;;, 30;3;-0.045312500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.045312500,0.0,0.0;;, 30;3;0.045312500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose7 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.105729167,0.0,0.0;;, 30;3;-0.105729167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.105729167,0.0,0.0;;, 30;3;0.105729167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.052864583,0.0,0.0;;, 30;3;-0.052864583,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.052864583,0.0,0.0;;, 30;3;0.052864583,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose8 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.120833333,0.0,0.0;;, 30;3;-0.120833333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.120833333,0.0,0.0;;, 30;3;0.120833333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.060416667,0.0,0.0;;, 30;3;-0.060416667,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.060416667,0.0,0.0;;, 30;3;0.060416667,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose9 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.135937500,0.0,0.0;;, 30;3;-0.135937500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.135937500,0.0,0.0;;, 30;3;0.135937500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.067968750,0.0,0.0;;, 30;3;-0.067968750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.067968750,0.0,0.0;;, 30;3;0.067968750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose10 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.151041667,0.0,0.0;;, 30;3;-0.151041667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.151041667,0.0,0.0;;, 30;3;0.151041667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.075520833,0.0,0.0;;, 30;3;-0.075520833,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.075520833,0.0,0.0;;, 30;3;0.075520833,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose11 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.166145833,0.0,0.0;;, 30;3;-0.166145833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.166145833,0.0,0.0;;, 30;3;0.166145833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.083072917,0.0,0.0;;, 30;3;-0.083072917,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.083072917,0.0,0.0;;, 30;3;0.083072917,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose12 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.181250000,0.0,0.0;;, 30;3;-0.181250000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.181250000,0.0,0.0;;, 30;3;0.181250000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.090625000,0.0,0.0;;, 30;3;-0.090625000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.090625000,0.0,0.0;;, 30;3;0.090625000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose13 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.196354167,0.0,0.0;;, 30;3;-0.196354167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.196354167,0.0,0.0;;, 30;3;0.196354167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.098177083,0.0,0.0;;, 30;3;-0.098177083,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.098177083,0.0,0.0;;, 30;3;0.098177083,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose14 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.211458333,0.0,0.0;;, 30;3;-0.211458333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.211458333,0.0,0.0;;, 30;3;0.211458333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.105729167,0.0,0.0;;, 30;3;-0.105729167,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.105729167,0.0,0.0;;, 30;3;0.105729167,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose15 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.226562500,0.0,0.0;;, 30;3;-0.226562500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.226562500,0.0,0.0;;, 30;3;0.226562500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.113281250,0.0,0.0;;, 30;3;-0.113281250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.113281250,0.0,0.0;;, 30;3;0.113281250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose16 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.241666667,0.0,0.0;;, 30;3;-0.241666667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.241666667,0.0,0.0;;, 30;3;0.241666667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.120833333,0.0,0.0;;, 30;3;-0.120833333,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.120833333,0.0,0.0;;, 30;3;0.120833333,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose17 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.256770833,0.0,0.0;;, 30;3;-0.256770833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.256770833,0.0,0.0;;, 30;3;0.256770833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.128385417,0.0,0.0;;, 30;3;-0.128385417,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.128385417,0.0,0.0;;, 30;3;0.128385417,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose18 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.271875000,0.0,0.0;;, 30;3;-0.271875000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.271875000,0.0,0.0;;, 30;3;0.271875000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.135937500,0.0,0.0;;, 30;3;-0.135937500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.135937500,0.0,0.0;;, 30;3;0.135937500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose19 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.286979167,0.0,0.0;;, 30;3;-0.286979167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.286979167,0.0,0.0;;, 30;3;0.286979167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.143489583,0.0,0.0;;, 30;3;-0.143489583,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.143489583,0.0,0.0;;, 30;3;0.143489583,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose20 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.302083333,0.0,0.0;;, 30;3;-0.302083333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.302083333,0.0,0.0;;, 30;3;0.302083333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.151041667,0.0,0.0;;, 30;3;-0.151041667,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.151041667,0.0,0.0;;, 30;3;0.151041667,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose21 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.317187500,0.0,0.0;;, 30;3;-0.317187500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.317187500,0.0,0.0;;, 30;3;0.317187500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.158593750,0.0,0.0;;, 30;3;-0.158593750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.158593750,0.0,0.0;;, 30;3;0.158593750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose22 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.332291667,0.0,0.0;;, 30;3;-0.332291667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.332291667,0.0,0.0;;, 30;3;0.332291667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.166145833,0.0,0.0;;, 30;3;-0.166145833,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.166145833,0.0,0.0;;, 30;3;0.166145833,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose23 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.347395833,0.0,0.0;;, 30;3;-0.347395833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.347395833,0.0,0.0;;, 30;3;0.347395833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.173697917,0.0,0.0;;, 30;3;-0.173697917,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.173697917,0.0,0.0;;, 30;3;0.173697917,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_Van_Pose24 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.362500000,0.0,0.0;;, 30;3;-0.362500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.362500000,0.0,0.0;;, 30;3;0.362500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.181250000,0.0,0.0;;, 30;3;-0.181250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.181250000,0.0,0.0;;, 30;3;0.181250000,0.0,0.0;;; } }
}
