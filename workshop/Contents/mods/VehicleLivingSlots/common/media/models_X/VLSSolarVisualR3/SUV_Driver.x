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
AnimationSet VLSSolarR3_SUV_Pose0 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.000000000,0.0,0.0;;, 30;3;-0.000000000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose1 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.014270833,0.0,0.0;;, 30;3;-0.014270833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.014270833,0.0,0.0;;, 30;3;0.014270833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.007135417,0.0,0.0;;, 30;3;-0.007135417,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.007135417,0.0,0.0;;, 30;3;0.007135417,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose2 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.028541667,0.0,0.0;;, 30;3;-0.028541667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.028541667,0.0,0.0;;, 30;3;0.028541667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.014270833,0.0,0.0;;, 30;3;-0.014270833,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.014270833,0.0,0.0;;, 30;3;0.014270833,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose3 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.042812500,0.0,0.0;;, 30;3;-0.042812500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.042812500,0.0,0.0;;, 30;3;0.042812500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.021406250,0.0,0.0;;, 30;3;-0.021406250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.021406250,0.0,0.0;;, 30;3;0.021406250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose4 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.057083333,0.0,0.0;;, 30;3;-0.057083333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.057083333,0.0,0.0;;, 30;3;0.057083333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.028541667,0.0,0.0;;, 30;3;-0.028541667,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.028541667,0.0,0.0;;, 30;3;0.028541667,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose5 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.071354167,0.0,0.0;;, 30;3;-0.071354167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.071354167,0.0,0.0;;, 30;3;0.071354167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.035677083,0.0,0.0;;, 30;3;-0.035677083,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.035677083,0.0,0.0;;, 30;3;0.035677083,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose6 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.085625000,0.0,0.0;;, 30;3;-0.085625000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.085625000,0.0,0.0;;, 30;3;0.085625000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.042812500,0.0,0.0;;, 30;3;-0.042812500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.042812500,0.0,0.0;;, 30;3;0.042812500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose7 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.099895833,0.0,0.0;;, 30;3;-0.099895833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.099895833,0.0,0.0;;, 30;3;0.099895833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.049947917,0.0,0.0;;, 30;3;-0.049947917,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.049947917,0.0,0.0;;, 30;3;0.049947917,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose8 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.114166667,0.0,0.0;;, 30;3;-0.114166667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.114166667,0.0,0.0;;, 30;3;0.114166667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.057083333,0.0,0.0;;, 30;3;-0.057083333,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.057083333,0.0,0.0;;, 30;3;0.057083333,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose9 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.128437500,0.0,0.0;;, 30;3;-0.128437500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.128437500,0.0,0.0;;, 30;3;0.128437500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.064218750,0.0,0.0;;, 30;3;-0.064218750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.064218750,0.0,0.0;;, 30;3;0.064218750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose10 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.142708333,0.0,0.0;;, 30;3;-0.142708333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.142708333,0.0,0.0;;, 30;3;0.142708333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.071354167,0.0,0.0;;, 30;3;-0.071354167,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.071354167,0.0,0.0;;, 30;3;0.071354167,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose11 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.156979167,0.0,0.0;;, 30;3;-0.156979167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.156979167,0.0,0.0;;, 30;3;0.156979167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.078489583,0.0,0.0;;, 30;3;-0.078489583,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.078489583,0.0,0.0;;, 30;3;0.078489583,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose12 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.171250000,0.0,0.0;;, 30;3;-0.171250000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.171250000,0.0,0.0;;, 30;3;0.171250000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.085625000,0.0,0.0;;, 30;3;-0.085625000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.085625000,0.0,0.0;;, 30;3;0.085625000,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose13 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.185520833,0.0,0.0;;, 30;3;-0.185520833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.185520833,0.0,0.0;;, 30;3;0.185520833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.092760417,0.0,0.0;;, 30;3;-0.092760417,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.092760417,0.0,0.0;;, 30;3;0.092760417,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose14 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.199791667,0.0,0.0;;, 30;3;-0.199791667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.199791667,0.0,0.0;;, 30;3;0.199791667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.099895833,0.0,0.0;;, 30;3;-0.099895833,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.099895833,0.0,0.0;;, 30;3;0.099895833,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose15 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.214062500,0.0,0.0;;, 30;3;-0.214062500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.214062500,0.0,0.0;;, 30;3;0.214062500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.107031250,0.0,0.0;;, 30;3;-0.107031250,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.107031250,0.0,0.0;;, 30;3;0.107031250,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose16 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.228333333,0.0,0.0;;, 30;3;-0.228333333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.228333333,0.0,0.0;;, 30;3;0.228333333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.114166667,0.0,0.0;;, 30;3;-0.114166667,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.114166667,0.0,0.0;;, 30;3;0.114166667,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose17 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.242604167,0.0,0.0;;, 30;3;-0.242604167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.242604167,0.0,0.0;;, 30;3;0.242604167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.121302083,0.0,0.0;;, 30;3;-0.121302083,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.121302083,0.0,0.0;;, 30;3;0.121302083,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose18 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.256875000,0.0,0.0;;, 30;3;-0.256875000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.256875000,0.0,0.0;;, 30;3;0.256875000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.128437500,0.0,0.0;;, 30;3;-0.128437500,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.128437500,0.0,0.0;;, 30;3;0.128437500,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose19 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.271145833,0.0,0.0;;, 30;3;-0.271145833,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.271145833,0.0,0.0;;, 30;3;0.271145833,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.135572917,0.0,0.0;;, 30;3;-0.135572917,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.135572917,0.0,0.0;;, 30;3;0.135572917,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose20 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.285416667,0.0,0.0;;, 30;3;-0.285416667,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.285416667,0.0,0.0;;, 30;3;0.285416667,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.142708333,0.0,0.0;;, 30;3;-0.142708333,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.142708333,0.0,0.0;;, 30;3;0.142708333,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose21 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.299687500,0.0,0.0;;, 30;3;-0.299687500,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.299687500,0.0,0.0;;, 30;3;0.299687500,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.149843750,0.0,0.0;;, 30;3;-0.149843750,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.149843750,0.0,0.0;;, 30;3;0.149843750,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose22 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.313958333,0.0,0.0;;, 30;3;-0.313958333,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.313958333,0.0,0.0;;, 30;3;0.313958333,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.156979167,0.0,0.0;;, 30;3;-0.156979167,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.156979167,0.0,0.0;;, 30;3;0.156979167,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose23 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.328229167,0.0,0.0;;, 30;3;-0.328229167,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.328229167,0.0,0.0;;, 30;3;0.328229167,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.164114583,0.0,0.0;;, 30;3;-0.164114583,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.164114583,0.0,0.0;;, 30;3;0.164114583,0.0,0.0;;; } }
}
AnimationSet VLSSolarR3_SUV_Pose24 {
Animation { { VehicleSkeleton } AnimationKey { 2; 2; 0;3;0.000000000,0.0,0.0;;, 30;3;0.000000000,0.0,0.0;;; } }
Animation { { SolarLeft } AnimationKey { 2; 2; 0;3;-0.342500000,0.0,0.0;;, 30;3;-0.342500000,0.0,0.0;;; } }
Animation { { SolarRight } AnimationKey { 2; 2; 0;3;0.342500000,0.0,0.0;;, 30;3;0.342500000,0.0,0.0;;; } }
Animation { { SolarMiddleLeft } AnimationKey { 2; 2; 0;3;-0.171250000,0.0,0.0;;, 30;3;-0.171250000,0.0,0.0;;; } }
Animation { { SolarMiddleRight } AnimationKey { 2; 2; 0;3;0.171250000,0.0,0.0;;, 30;3;0.171250000,0.0,0.0;;; } }
}
