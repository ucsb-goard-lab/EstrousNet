# EstrousNet

EstrousNet is a novel deep learning pipeline for unbiased classification of estrous stage. To emulate human classification more closely, the EstrousNet algorithm fits test images to an archetypal estrous cycle, avoiding common confusion errors. Final classifications surpass expert accuracy and speed.

IMPORTANT: If you are using the pretrained network to classify images with EstrousNet, you must download the code over Git command line. The pretrained net is uploaded via GitHub's Large File Storage system, and files downloaded to a zipped folder on GitHub desktop will not contain the full 84MB pretrained network file. Alternatively, you may download the full file on GitHub desktop by navigating to it directly and clicking the "Download" button above the "View Raw" hyperlink. 

For image classification on pretrained network
1) In MATLAB, navigate to the folder containing the EstrousNet code.
2) DOUBLE CHECK that all the EstrousNet code, including subfolders, are added to your path.
3) Make sure all necessary MATLAB packages are installed, including Image Processing Toolbox, Statistics and Machine Learning Toolbox, Deep Learning Toolbox, and Deep Learning Toolbox Model for ResNet-50 Network, or whichever base architecture you are using.
4) Run the GUI by executing “EstrousNetGUI” from MATLAB’s command window.
5)  Select your folder of test images, and whether your images were taken sequentially. EstrousNet accepts images of type JPG, PNG, and BMP. Smaller images will result in a faster classification, but are not necessary for high accuracy. 
6)  Hit “RUN ESTROUSNET”, and watch your classifications appear!


To train your own network
1) Follow steps 1-3 to set up the EstrousNet GUI.
2) In the 3rd panel of the GUI, under "Do you want to train a new network", toggle the switch to "Yes". This should automatically launch the Training GUI.
3) In the Training GUI, select your training and validation folders, and change augmentation parameters or base architecture if desired. It should be noted that both the augmentation parameters and base architecture have been preset for greatest speed and accuracy.
4) Hit “TRAIN ESTROUSNET” and watch your machine learn!


Once classifications are complete, you will be asked if you want to save your results to the current directory. 
The results output will be saved as a structure, with the following fields:

trainedNet:          Pretrained network imported into GUI.

testFolder:          Path of the folder containing your test images.

rawImages:           Image datastore of unprocessed test images.

processed Images:    Image datastore of test images after luminance normalization and conversion to greyscale.

finalLabels:         Final classifications for each image, with net labels changed to cyclicity labels in all instances specified by the user.

cyclicityLabels:     Classifications that most closely correspond to an archetypal estrous cycle.

labelProbabilities:  Classifications for each test image broken down by probability for all estrous stages.


For contributions or comments, contact Nora Wolcott at nora.wolcott@lifesci.ucsb.edu.
