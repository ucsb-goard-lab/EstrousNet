# EstrousNet

EstrousNet is a novel deep learning pipeline for unbiased classification of estrous stage. To emulate human classification more closely, the EstrousNet algorithm fits test images to an archetypal estrous cycle, avoiding common confusion errors. Final classifications surpass expert accuracy and speed.


For image classification on pretrained network
1) In MATLAB, navigate to the folder containing the EstrousNet code.
2) Make sure all necessary MATLAB packages are installed, including Deep Learning Toolbox and Deep Learning Toolbox Model for ResNet-50 Network, or whichever base    architecture you are using.
3) Run the GUI by executing “EstrousNetGUI” from MATLAB’s command window.
4)  Select your folder of test images, and whether your images were taken sequentially.
5)  Hit “RUN ESTROUSNET”, and watch your classifications appear!


To train your own network
1) Follow steps 1-3 to set up the EstrousNet GUI.
2) In the 3rd panel of the GUI, under "Do you want to train a new network", toggle the switch to "Yes". This should automatically launch the Training GUI.
3) In the Training GUI, select your training and validation folders, and change augmentation parameters or base architecture if desired. It should be noted that both the augmentation parameters and base architecture have been preset for greatest speed and accuracy.
4) Hit “TRAIN ESTROUSNET” and watch your machine learn!


For contributions or comments, contact Nora Wolcott at nora.wolcott@lifesci.ucsb.edu.
