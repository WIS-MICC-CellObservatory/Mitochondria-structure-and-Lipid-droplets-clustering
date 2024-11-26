/***
V15: 1. we do not calculate the area of teh LD as is because their size is too close to the microscope resolution. 
     Hence we multiply the LD mean intensity by the size, as a way to compare LD sizes (and not get a real size in nm)
     To get the mean intensity - we substract the background mean intensity from the ld mean intensity
     to get the background mean intensity we look at the mean intensity of the cell without the LDS
     2. To calculate the mitochondria aspect ratio we first calculate its mean width by:
		2.1. make 2 copies of mask of the mitochondria
		2.2. skeletonize one
		2.3. run local thickness on the other
		2.4. multiply the images (and divide by 255) - to get only the thicness at the skelaton
		2.5. look at the statistics of the skeleton in the resulting multiplication
		2.6. the mean width of that result image is the width needed for the aspect ratio
		Then we calculate the mean length by:
		2.7 take the total area of mito in the cell deivide it by number of mito rois to get the average area size 
		2.8 then devide it by width to get average length
		The aspect ratio is given by: 
											0.25PI*(mean length/mean width)
1.	The full analysis consist of the following for each file:
1.1.	Make a z-project off all slices
1.2.	Identify cells (don’t ignore cells touching borders?) using Sabita’s trained model in Cellpose (trained on Mitochondria channel only?)
1.3.	Identify Lipid Droplets (LD) using Stardist on a scaled up version of the1st channel of the image (configurable parameters)
1.4.	Identify clusters of LDs using SSIDC algorithm (configurable parameters)
1.5.	Categorize cells according to ratio between clustered LDs and non-clustered LDs (configurable parameters):
1.5.1.	Clustered
1.5.2.	Intermediate
1.5.3.	Non-clustered
1.6.	Identify mitochondria within each cell using Sabita’s trained model in Ilastik (trained on Mitochondria channel only)
1.7.	Calculate the area of each mitochondria, make a histogram of percentage of mitochondria in three area ranges (configurable):
1.7.1.	Long
1.7.2.	Intermediate
1.7.3.	Short
1.8.	Calculate the Aspect ratio of the mitochondria
1.9.	Check LD clustering
2.	Accumulated information:
2.1.	For all files from the same time (file name convention), accumulate the information depending on the information: To be defined…
***/

#@ String(label="Process Mode", choices=("singleFile", "wholeFolder", "AllSubFolders"), style="list") iProcessMode
//var iProcessMode = "singleFile";
#@ String(label="File Extension",value=".nd2", persist=true, description="eg .tif, .nd2") iFileExtension


#@ File (label="Mito Ilastik model path",value="A:\\UserData\\ehuds\\Projects\\Sabita\\Mitochondria_LD\\Mito.ilp", persist=true, description="Ilastik model path") iIlastikModelPath

#@ String(label="Mito min size (pixels)",value="3", persist=true, description="below this number mitochondria is considered 'fregmented'") iMitoMinSize
#@ String(label="Mito max frgemented area (micron^2)",value="2", persist=true, description="below this number mitochondria is considered 'fregmented'") iMitoMaxFregmented
#@ String(label="Mito min elongated area (micron^2)",value="4", persist=true, description="above this number mitochondria is considered 'elongated'") iMitoMinElongated
#@ String(label="Mito min hyper elongated area (micron^2)",value="4", persist=true, description="above this number mitochondria is considered 'elongated'") iMitoMinHyperElongated
#@ String(label="Mito slice number",value="4", persist=true, description="the slice in Z to use for mito segmentation") iMitoSlice
#@ Integer(label="background substraction sliding window length",value="10", persist=true,  description="0 if no background substraction is required") iBackgroundSubstractor
#@ Integer(label="LD intensity threshold",value="300", persist=true, description="lower intensity LD to be ignored") iLDIntensityThreshold
#@ Float(label="LD Max size (micron^2)",value="2", persist=true, description="LD larger than this size will be ignored") iLDMaxSize

#@ File(label="Cell Cellpose, Model full path",value="C:\\Users\\ehuds\\.cellpose\\models\\SabitaMitoCellpose", persist=true, description="the one stored in C:/Users/UserName/.cellpose/models") iMitoCellposeModelPath
#@ String(label="Cell Cellpose, Cell diameter",value="316", persist=true, description="as set in training") iMitoCellposeCellDiameter
#@ Integer(label="Cell min area(pixel^2)",value="1000", persist=true, description="FIlter out small objects identified by Cellpose") iMinCellAreaSize
#@ Integer(label="Cell dilation(pixels)",value="10", persist=true, description="nonoverlap dilation to capture LDs beyond metochondria") iDilationSize

#@ String(label="SSIDC, LD cluster distance (micron)",value="20", persist=true, description="distance to cluster LDs") iLDclusterDistance
#@ String(label="SSIDC, LD cluster min density",value="3", persist=true, description="min density to cluster LDs") iLDminDensity

#@ Integer(label="LD Channel",value="1", persist=true) gLDChannel
#@ Integer(label="Mitochondria Channel",value="3", persist=true) gMitoChannel
#@ Integer(label="Dapi Channel",value="4", persist=true) gDapiChannel
#@ File(label="Ilastik, executable",value="C:\\Program Files\\ilastik-1.3.3post3\\ilastik.exe", persist=true, description="Ilastik executable") iIlastikExe
#@ File(label="Cellpose, Enviorenment",value="C:\\ProgramData\\anaconda3\\envs\\cellpose", style="directory", persist=true, description="Cellpose env.") iCellposeEnv
#@ Boolean(label="Use external run for cell segmentation",value=true, persist=true, description="for quicker runs, use batch Cellpose results, if exists") iUseExternalCellposeRun
#@ String(label="Cell segmentation External run sub-directory",value="MitoCellpose/Segmentation/", persist=true, description="the subdirectory in the input folder where the label image with the segmentation resides") iMitoCellposeExtRunDir
#@ String(label="Cell segmentation file name suffix",value="_cp_masks.tif", persist=true, description="this suffix is added to the image file name to get the segmentation file name") iCellposeExtRunFileSuffix

iMitoMaxFregmented = parseFloat(iMitoMaxFregmented);
iMitoMinElongated = parseFloat(iMitoMinElongated);
iMitoMinHyperElongated = parseFloat(iMitoMinHyperElongated);

//----Macro parameters-----------
var pMacroName = "Mito_CellposeLD";
var pMacroVersion = "3.0.0";


//----- global variables-----------
var gCellsLabelsImageId = -1;
var gLDsFilteredLabelsImageId = -1;
var gLDsAllLabelsImageId = -1;
var gMitoZimageId = -1;
var gDapiZimageId = -1;
var gTempROIFile = "tempROIs.zip";
var gIlastikSegmentationExtention = "_Segmentations Stage 2.h5"; // "_Segmentations.h5"
var gNumCells = -1;
var gStarDistWindowTitle = "Label Image";
var gLDZimageId = -1;
var gManualRoi = false;
var gFirstClusterRoi = true;
var gMitoMaskImageId = -1;

var gRoiLineSize = 2;
var gCellsColor = "yellow";
var gLDsColor = "red";
var gClustersColor = "blue";
var gMitoColor = "pink";
var gFileFullPath = "uninitialized";
var gFileNameNoExt = "uninitialized";
var gResultsSubFolder = "uninitialized";
var gImagesResultsSubFolder = "uninitialized";
var gMainDirectory = "uninitialized";
var gSubFolderName = "";

var gSaveRunDir = "SaveRun"
var gLDRois = "uninitializeds";
var gCellsRois = "uninitialized";
var gClustersRois = "Uninitializd";
var gMitoRois = "uninitialized";
//var gLDCellposeModel = "LDCellpose";
//var gMitoCellposeModel = "MitoCellpose";

var	gCompositeTable = "CompositeResults.xls";
var	gAllCompositeTable = "allCompositeTable.xls";
var gAllCompositeResults = 0; // the comulative number of rows in allCompositeTable

//var gInitiatedCellpose = false;
var gInitiatedIlastik = false;

var width, height, channels, slices, frames;
var unit,pixelWidth, pixelHeight;



//-----debug variables--------
var gDebugFlag = false;
var gBatchModeFlag = false;
//------------Main------------
Initialization();
if(LoopFiles()) 
	print("Macro ended successfully");
else
	print("Macro failed");
CleanUp(true);
waitForUser("=================== Done ! ===================");

	
function ProcessFile(directory) 
{
	run("Collect Garbage");
	setBatchMode(gBatchModeFlag);
	
	File.makeDirectory(gResultsSubFolder);
	if(!openFile(gFileFullPath))
		return false;
	gFileNameNoExt = File.getNameWithoutExtension(gFileFullPath);
//	gImagesResultsSubFolder = gResultsSubFolder + "/" + gFileNameNoExt;	
	gImagesResultsSubFolder = gResultsSubFolder + gFileNameNoExt;	
	File.makeDirectory(gImagesResultsSubFolder);
	File.makeDirectory(gImagesResultsSubFolder+"/"+gSaveRunDir);
	run("Select None");
	imageId = DoubleGetImageId();
	rename(gFileNameNoExt);
	initVariables();
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit,pixelWidth, pixelHeight);	
	
	//prepare image for Ilastik and cellpose
	gMitoZimageId = DupChannelAndZProject(imageId,gMitoChannel, "Max Intensity");
	//waitForUser("check gMitoZimageId: "+gMitoZimageId);
	gDapiZimageId = DupChannelAndZProject(imageId,gDapiChannel, "Max Intensity");
	//Get Mitochondria mask using Ilastik
	GetMitoRois(imageId);
	//Get labelmap of cells using cellpose
	GetCellsRois();
	//Get Lipid droplets labeled image
	gLDsFilteredLabelsImageId = GetLDsLabeledImage(imageId);

	Table.create(gCompositeTable);
			
	for(i=0;i<gNumCells;i++)
	{
		ProcessCell(i);
	}
	
	//add a cell of the entire image - dilation
	getDimensions(width, height, channels, slices, frames);
	makeSelection("polygon",newArray(0,0,width,width),newArray(0,height,height,0));
	roiManager("add");
	saveDilationSize = iDilationSize;
	iDilationSize = 0;
	roiManager("select", gNumCells);
	roiManager("rename", "Whole image");
	ProcessCell(gNumCells);
	iDilationSize = saveDilationSize;
	gNumCells++;
	
	gAllCompositeResults += gNumCells;
	// make nice pictures for the paper
	GenerateOverlayImages();
	fullPath = gImagesResultsSubFolder+"/"+gFileNameNoExt+".csv";
	//save statistics table
	Table.save(fullPath,gCompositeTable);	
	CloseTable(gCompositeTable);
	return true;
}


function RunCellpose_LSCF(imageId, model, diameter, ch1, ch2, additional_flags, cellposeEnv){
	selectImage(imageId);
	modelAndPath = " model="+model+" model_path=path\\to\\own_cellpose_model";
	if(File.exists(model)){
		modelAndPath = "model= model_path=["+model+"]";
	}
	run("Cellpose ...", "env_path=["+cellposeEnv+"] env_type=conda" + modelAndPath + " diameter="+diameter + " ch1="+ch1 + " ch2="+ch2 + " additional_flags="+additional_flags);
	return getImageID();
}

function GetMitoRois(imageId)
{
	middleSliceImageId = DupSlice(imageId,gMitoChannel, iMitoSlice);
	gMitoMaskImageId = RunIlastikModel(middleSliceImageId);
	// generate rois and save them for image output
	DoubleSelectImageId(gMitoMaskImageId);
	ClearRoiManager();	
	// turn the Mito mask into rois (2 is the value of the mito in the mask and 1 is the background)
	setThreshold(2, 1000000000000000000000000000000.0000);
	//waitForUser("check pixel size");
	run("Analyze Particles...", "size="+iMitoMinSize+"-Infinity display summarize add composite"); 	
	roiManager("deselect");
	if(roiManager("count") <= 0)
	{
			print("Fatal Error: no mitochondria identified - remove file from directory - or change suffix");
			return;
	}
	if(iMitoMinSize > 0){
		n = roiManager("count");
		rois = Array.getSequence(n);
		roiManager("select",rois);
		roiManager("combine");
		roiManager("add");
		roiManager("deselect");
		roiManager("select", n);
		run("Clear Outside");
		roiManager("select", n);
		roiManager("deselect");
		roiManager("select", n);
		roiManager("delete");
		//waitForUser("check mask");
	}
	roiManager("save", gMitoRois);
	//calculate 
	ClearRoiManager();
	
}
function initVariables()
{
	gFirstClusterRoi = true;
	
	gCellsRois = gImagesResultsSubFolder+'/'+"Cells_rois.zip";
	gLDRois = gImagesResultsSubFolder+'/'+"LDs_rois.zip";
	gClustersRois = gImagesResultsSubFolder+'/'+"Clusters_rois.zip";
	gMitoRois = gImagesResultsSubFolder+'/'+"Mito_rois.zip";
	if(File.exists(gCellsRois)){
		File.delete(gCellsRois);
	}	
	if(File.exists(gLDRois)){
		File.delete(gLDRois);
	}	
	if(File.exists(gClustersRois)){
		File.delete(gClustersRois);
	}
	if(File.exists(gMitoRois)){
		File.delete(gMitoRois);
	}
}

function GetCellsRois()
{
	gManualRoi = false;
	DoubleSelectImageId(gMitoZimageId);
	title1 = getTitle();
	DoubleSelectImageId(gDapiZimageId);
	title2 = getTitle();
	run("Merge Channels...", "c1=["+title1+"] c2=["+title2+"] create keep");
	selectWindow("Composite");
	compositeImageId = DoubleGetImageId();
	gCellsLabelsImageId = RunCellposeModel(compositeImageId);
	//filter out small cells
	DoubleSelectImageId(gCellsLabelsImageId);
	//waitForUser("before filter: " + getTitle());
	//run("Label Size Filtering", "operation=Greater_Than size="+iMinCellAreaSize);
	gCellsLabelsImageId = DoubleGetImageId();
	run("Label Size Filtering", "operation=Greater_Than size="+iMinCellAreaSize);
	filteredImageId = DoubleGetImageId();
	DoubleSelectImageId(gCellsLabelsImageId);
	close();
	gCellsLabelsImageId = filteredImageId;
	GenerateROIsFromLabelImage(gCellsLabelsImageId,"Cell",0);
	//waitForUser("BEFORE filter: " + iMinCellAreaSize);
	//FilterRois(compositeImageId, "Area",">",iMinCellAreaSize);
	//waitForUser("BEFORE filter: " + getTitle());
	//waitForUser("after filter: " + getTitle());
	gNumCells = roiManager("count");
	DoubleSelectImageId(gCellsLabelsImageId);
	if(gNumCells <= 0)
	{
		title = getTitle();
		print("WARNING!!!: Cellpose did not identify any cell/object in " + title);
	}
	else{
		if(iDilationSize != 0){
			EnlargeAllRoisNoOverlaps(iDilationSize);
		}
	}
	FilterRois(gCellsLabelsImageId, "Area",">",iMinCellAreaSize);
	gNumCells = roiManager("count");
		for(i=gNumCells-1;i>=0;i--){
		roiManager("deselect");
		roiManager("select", i);
		roiManager("rename", "Cell_"+(i+1));
	}
	SaveROIs(gCellsRois);	
	//waitForUser("CHECK ROIS:"+gCellsRois);
}


function GetLDsRois()
{
	ClearRoiManager();
	//if(iUseStardistSegmentation){
	starDistImageId = gLDZimageId;
	if(iBackgroundSubstractor > 0){
		run("Duplicate...", "title=background_substracted ignore");
		run("Background Subtractor", "length="+iBackgroundSubstractor);
		starDistImageId = DoubleGetImageId();
	}
	gLDsAllLabelsImageId = RunStarDistModel(starDistImageId);
	gNumLDs = roiManager("count");
	//}
	//else{
	//	gLDsAllLabelsImageId = RunCellposeModel(iLDCellposeExtRunDir);
	//	gNumLDs = GenerateROIsFromLabelImage(gLDsAllLabelsImageId,"",0);
	//}
	DoubleSelectImageId(gLDZimageId);

	gNumLDs = FilterRois(gLDZimageId,"Area","<", iLDMaxSize);
	//threshold = FindThresholdByPercentage(gLDZimageId,"Mean",iLDIntensityThreshold);
	gNumLDs = FilterRois(gLDZimageId, "Mean",">", iLDIntensityThreshold);

	if(gNumLDs <= 0)
	{
		print("WARNING!!!: segmentation did not identify any LD in " + getTitle());
	}
	run("ROIs to Label image");
	gLDsFilteredLabelsImageId = DoubleGetImageId();
	
	//waitForUser("gLDRois: "+gLDRois);
	SaveROIs(gLDRois);
	//StoreROIs(gImagesResultsSubFolder,gLDRois);	
	return gLDsFilteredLabelsImageId;
}



function FilterRois(imageId, measure,operation,threshold){
	rois = newArray(0);
	deleted=0;
	DoubleSelectImageId(imageId);
	run("Clear Results");
	roiManager("deselect");
	roiManager("measure");
	n = roiManager("count");
	measures = Table.getColumn(measure, "Results");
	
	for(i=n-1;i>=0;i--)
	{
		//waitForUser("measures[i]: "+measures[i]+" operation: "+operation+" threshold: "+threshold);
		if(!ApplyOperation(measures[i], operation, threshold)){
			//waitForUser("i: "+i);
			rois[deleted++]=i;
		}
	}
	if(deleted > 0){
		roiManager("select", rois);
		roiManager("delete");
	}
	//waitForUser("after filter");
	return roiManager("count");
}

function ApplyOperation(value, operation,threshold){
	script = "r = " + value + " " + operation + " " + threshold + "; return toString(r);";
////	waitForUser(script);
	result = parseInt(eval(script));
	return result;
}

function ProcessCell(roiId)
{
	tmpROIFullPath = gImagesResultsSubFolder+"/"+gTempROIFile;
	if(!matches(iProcessMode, "singleFile"))
		Table.set("File Name",gAllCompositeResults+roiId,gFileFullPath,gAllCompositeTable);
		
	SaveROIs(tmpROIFullPath);
	
	
	roiManager("select", roiId);
	roi_name = Roi.getName;


	SetCompositeTables("Cell ID",roiId,roi_name);
	SetCompositeTables("Manual Cell roi",roiId,gManualRoi);

	
	//check LD clustering in cell
	AnalyzeLDs(roiId,tmpROIFullPath);
	// calculate the area of each mito type (fregemented, intermidiate or elongated)
	AnalyzeMito(roiId, tmpROIFullPath);	
	

}

function GenerateOverlayImages()
{
	cellsRoiPath = gCellsRois;
	if(gManualRoi)
		cellsRoiPath += "_Manual.zip";

	ldsRoiPath = gLDRois;
	clustersRoiPath = gClustersRois;
	mitoRoiPath = gMitoRois;
	

	//1st image: cells, LDs, and clusters ROIs in three colors on top of LDs channel
	ClearRoiManager();
	
	if(File.exists(cellsRoiPath))
	{
		roiManager("Open", cellsRoiPath);
		roiManager("Deselect");		
		roiManager("Set Color", gCellsColor);
		roiManager("Set Line Width", gRoiLineSize);
	}
	else
		print("Warning: No cells Rois found");
	nBefore = roiManager("count");
	if(File.exists(ldsRoiPath))
	{
		roiManager("Open", ldsRoiPath);
		nAfter = roiManager("count");
		for(i=nBefore;i<nAfter;i++)
		{
			roiManager("select", i);
			roiManager("Set Color", gLDsColor);
			roiManager("Set Line Width", 1);
		}
	}
	else
		print("Warning: No LDs Rois found");
		
	nBefore = roiManager("count");
	if(File.exists(clustersRoiPath))
	{
		roiManager("Open", clustersRoiPath);
		nAfter = roiManager("count");
		for(i=nBefore;i<nAfter;i++)
		{
			roiManager("select", i);
			roiManager("Set Color", gClustersColor);
			roiManager("Set Line Width", 1);
		}
	}
	else
		print("Warning: No clusters Rois found");
		
	DoubleSelectImageId(gLDZimageId);
	run("Enhance Contrast", "saturated=0.35");
	roiManager("Deselect");
	roiManager("Show All without labels");
	saveAs("Tiff",gImagesResultsSubFolder+"/LDs.tif");
	run("Flatten");
	saveAs("Jpeg", gImagesResultsSubFolder+"/LDs.jpg");
	
	//2nd image: cells, and mito ROIs in two colors on top of Mito. channel
	ClearRoiManager();
	
	if(File.exists(cellsRoiPath))
	{
		roiManager("Open", cellsRoiPath);
		roiManager("Deselect");		
		roiManager("Set Color", gCellsColor);
		roiManager("Set Line Width", gRoiLineSize);
	}

	nBefore = roiManager("count");
	if(File.exists(mitoRoiPath))
	{
		roiManager("Open", mitoRoiPath);
		nAfter = roiManager("count");
		for(i=nBefore;i<nAfter;i++)
		{
			roiManager("select", i);
			roiManager("Set Color", gMitoColor);
			roiManager("Set Line Width", 1);
		}
	}
	else
		print("Warning: No mito Rois found");
		
	DoubleSelectImageId(gMitoZimageId);
	run("Enhance Contrast", "saturated=0.35");
	roiManager("Deselect");
	roiManager("Show All without labels");
	saveAs("Tiff",gImagesResultsSubFolder+"/Mito.tif");
	run("Flatten");
	saveAs("Jpeg", gImagesResultsSubFolder+"/Mito.jpg");
}

function AnalyzeMito(roiId, tmpROIFullPath)
{
	//remove all Mito outside of cell
	DoubleSelectImageId(gMitoMaskImageId);
	//waitForUser("mito:"+getTitle());
	run("Duplicate...", "title=Cell_Mito_"+roiId+" ignore");
	roiManager("select", roiId);
	//waitForUser("roiId: "+roiId);
	roi_name = Roi.getName;
	run("Clear Outside");
	//waitForUser("after clear: "+roiId);
	//waitForUser("check mito: "+roiId);
	// turn the Mito mask into rois (2 is the value of the mito in the mask and 1 is the background)
	ClearRoiManager();	
	run("Select None");
	setThreshold(2, 255, "raw");
	run("Analyze Particles...", "size="+iMitoMinSize+"-Infinity display summarize add composite");
	//id = ;
	//waitForUser("check roi");
	CalcMitoAspectRatio(DoubleGetImageId(),roiId);

	//calculate relative area of each each mito type (fregemented, intermidiate or elongated)
	DoubleSelectImageId(gMitoZimageId);
	//waitForUser("gMitoZimageId: "+gMitoZimageId);
	roiManager("deselect");
	run("Clear Results");
	roiManager("measure");
	n = roiManager("count");
	//waitForUser("check mito n: "+n);
	totalArea = 0; fregmenetArea = 0; elongatedArea = 0; hyperElongatedArea = 0;
	//print("++++");
	for(i=0;i<n;i++)
	{
		area = Table.get("Area",i, "Results");// * pixelWidth * pixelHeight;
//		print("area,totalarea,i: "+area+","+totalArea+","+i);
	//	if(area > 1000 || totalArea > 2000)
	//		waitForUser("check results and rois: "+area+","+totalArea+","+i);
		totalArea += area;
		if(area <  iMitoMaxFregmented)
			fregmenetArea += area;
		else if(area > iMitoMinHyperElongated)
			hyperElongatedArea += area;
		else if(area > iMitoMinElongated)
			elongatedArea += area;
	}	
	// add to cell table
	SetCompositeTables("Mito. Total area",roiId,totalArea);
	SetCompositeTables("Mito. fregmented size area (<"+iMitoMaxFregmented+"m^2)",roiId,fregmenetArea);
	SetCompositeTables("Mito. intermidiate size area",roiId,totalArea-fregmenetArea-elongatedArea-hyperElongatedArea);
	SetCompositeTables("Mito. elongated size area (>"+iMitoMinElongated+"m^2)",roiId,elongatedArea);
	SetCompositeTables("Mito. hyper elongated size area (>"+iMitoMinHyperElongated+"m^2)",roiId,hyperElongatedArea);
	//save mito measurments
	
	
	fullPath = gImagesResultsSubFolder+"/"+roi_name+"_Mito.csv";
	//save statistics table
	Table.save(fullPath,"Results");	
	CloseTable("Results");

	ClearRoiManager();
	roiManager("Open", tmpROIFullPath);
}
function CalcMitoAspectRatio(gMitoImageId,roiId){
		numMitos = roiManager("count");
		if(numMitos <= 0){
			return;
		}

		DoubleSelectImageId(gMitoImageId);

		//First calculate the mean width of the mitochondria:
		//1. make 2 copies of mask of the mitochondria
		//2. skeletonize one
		//3. run local thickness on the other
		//4. multiply the images (and divide by 255)
		//5. look at the statistics of the skeleton in the resulting multiplication
		//6. the mean width of that result image is the width needed for the aspect ration
		run("Duplicate...", "title=[Cell_Mito_Mask11"+roiId+"] ignore");
		//waitForUser("check dup");		
		setThreshold(1, 255, "raw");		
		run("Convert to Mask");
		//waitForUser("check converted mask");
		getStatistics(area, mean, min, max, std, histogram);
		//waitForUser("area, mean, min, max, std, histogram: "+area+","+mean+","+min+","+max+","+std+","+histogram[255]);
		mitoArea = histogram[255];
		mitoMaskImageId = DoubleGetImageId();
		run("Duplicate...", "title=[Cell_Mito_Mask_skeleton"+roiId+"] ignore");
		run("Skeletonize");
		//waitForUser("check skeleton");
		mitoMaskImageSkeletonId = DoubleGetImageId();
		skeletonTitle = getTitle();
		DoubleSelectImageId(mitoMaskImageId);
		//waitForUser("check mask");
		run("Local Thickness (masked, calibrated, silent)");
		cellMitoMasklocThickImageId = DoubleGetImageId();
		thicknessTitle = getTitle();
		imageCalculator("Multiply", thicknessTitle,skeletonTitle);
		run("Divide...", "value=255.000");
		//waitForUser("check thickness and skeleton");
		DoubleSelectImageId(mitoMaskImageSkeletonId);
		run("Create Selection");
		DoubleSelectImageId(cellMitoMasklocThickImageId);
		run("Restore Selection");
		getStatistics(area, mean, min, max, std, histogram);
		meanWidth = mean;
		//waitForUser("meanWidth:"+meanWidth);
		
		//take the total area of mito in the cell deivide it by number of mito rois to get the average area size then devide it by width to get average length and then divide it by width again to get aspect ratio
		ar = (PI/4)*mitoArea/numMitos/meanWidth/meanWidth;
		//waitForUser("id,area,num mitos,width, ar:"+roiId+","+mitoArea+","+","+numMitos+","+meanWidth+","+ar);
		SetCompositeTables("Mito. AR",roiId,ar);

		DoubleSelectImageId(mitoMaskImageId);
		close();
		//print("closed 1: "+mitoMaskImageId);
		DoubleSelectImageId(mitoMaskImageSkeletonId);
		close();
		//print("closed 2: "+mitoMaskImageSkeletonId);
		DoubleSelectImageId(cellMitoMasklocThickImageId);
		close();
		//print("closed 3: "+cellMitoMasklocThickImageId);
		//waitForUser("Branch avg. AR: "+ (totalLength/numBranches/meanWidth));
}
function SetCompositeTables(colName,rowId,colValue)
{
	Table.set(colName,rowId,colValue,gCompositeTable);
	if(!matches(iProcessMode, "singleFile"))
		Table.set(colName,gAllCompositeResults+rowId,colValue,gAllCompositeTable);
}

function AnalyzeLDs(roiId,tmpROIFullPath)
{
	background_intensity = calc_organel_background_intensity(roiId, tmpROIFullPath);
	
	//remove all LDs outside of cell
	DoubleSelectImageId(gLDsFilteredLabelsImageId);
	run("Duplicate...", "title=Cell_Filtered_LDs_"+roiId+" ignore");	
	imageId = DoubleGetImageId();
	run("Select None");
	roiManager("deselect");
	roiManager("select", roiId);
	roi_name = Roi.getName;
	run("Clear Outside");
	//run("Remove Largest Label");

	run("Label image to ROIs");
	numLDs = roiManager("count");
	//waitForUser("numLDs: "+numLDs);
	avgLDSizeXIntensity = 0.0;
	avgLDSize = 0.0;
	numClusters = 0;
	numClusteredLDs = 0;
	if(numLDs > 0){
		DoubleSelectImageId(gLDZimageId);
		run("Clear Results");
		roiManager("deselect");
		roiManager("measure");
		//waitForUser("check results table");
		ld_areas = Table.getColumn("Area","Results");
		ld_mean_intensity = Table.getColumn("Mean","Results");
			
		//erode LDs labels
		erodedLabelsImageId = ErodeLabels(imageId);
	
		//waitForUser("check image");
		run("Duplicate...", "title=dup_for_SSIDC_"+roiId+" ignore");	
		//count the total number of LDs in cell
		ClearRoiManager();
		run("Label image to ROIs");

		for(i=numLDs-1;i>=0;i--){
			avgLDSizeXIntensity += ld_areas[i]*(ld_mean_intensity[i]-background_intensity);
			avgLDSize += ld_areas[i];
		}
		//waitForUser("check lds of cell: "+roiId);
		//AppendRois(gLDRois);	
		avgLDSizeXIntensity = avgLDSizeXIntensity/numLDs;
		avgLDSize = avgLDSize/numLDs;
		run("ROIs to Label image");
		filters_lds_image_id = DoubleGetImageId();
		ClearRoiManager();
		//run("Threshold...") for SSIDC clustering
		//waitForUser("check clustering image");
		binaryImageId = RunThreshold(1, 65535);
		// SSIDC clustring
		run("SSIDC Cluster Indicator", "distance="+iLDclusterDistance +" mindensity="+iLDminDensity);
		// remove all clusters and replace them with a single roi combining the all
		numClusters = roiManager("count");
		if(numClusters > 1){
			roiManager("select", Array.getSequence(numClusters));
			roiManager("combine");
			ClearRoiManager();
			roiManager("Add");
		}
		if(numClusters > 0)
		{
	
			//in the labeled image of LDs in cell remove all non-clustered LDs
			//DoubleSelectImageId(erodedLabelsImageId);
			//save clusters rois
			if(!gFirstClusterRoi)
			{
				// add prev clusters
				roiManager("open", gClustersRois);
			}
			else
				gFirstClusterRoi = false;
	
			
	
	
			roiManager("select", 0);
			roiManager("rename", roi_name+"_Clusters");
			roiManager("deselect");
			roiManager("save", gClustersRois);
	
			//DoubleSelectImageId(erodedLabelsImageId);
			roiManager("select", 0);
			//run("Clear Outside");
			//count the total number of clusterd LDs in cell
			ClearRoiManager()	;
			run("Manual Threshold...", "min=1 max=100000");
			run("Analyze Particles...", "size=0-Infinity display summarize add composite");
		
			//waitForUser("check lds again");	
			//run("Label image to ROIs");
			numClusteredLDs = roiManager("count");
			DoubleSelectImageId(filters_lds_image_id);
			close();
			//print("closed 4: "+filters_lds_image_id);
			
		}
	}

	// add to cell table
	SetCompositeTables("No. LDs",roiId,numLDs);
	SetCompositeTables("Avg. LD size (microns^2)",roiId,avgLDSize);
	SetCompositeTables("Avg. LD size (area x intensity)",roiId,avgLDSizeXIntensity);
	SetCompositeTables("No. clusters",roiId,numClusters);
	SetCompositeTables("No. Clustered LDs",roiId,numClusteredLDs);
	
	ClearRoiManager();
	roiManager("Open", tmpROIFullPath);
}

function calc_organel_background_intensity(roiId, tmpROIFullPath){
	//first get the mean intensity of the entire cell for background calculation
	DoubleSelectImageId(gLDZimageId);
	roiManager("select", roiId);
	getStatistics(cell_area, cell_mean_intensity);
	
	//get size and intensity of all identified LDs in cell to be ignored from background
	DoubleSelectImageId(gLDsAllLabelsImageId);
	run("Duplicate...", "title=Cell_All_LDs_"+roiId+" ignore");
	imageId = DoubleGetImageId();	
	run("Select None");
	roiManager("deselect");
	roiManager("select", roiId);
	run("Clear Outside");
	run("Label image to ROIs");

	DoubleSelectImageId(gLDZimageId);
	run("Clear Results");
	roiManager("deselect");
	if(roiManager("count") > 0){
		roiManager("measure");
		organel_areas = Table.getColumn("Area","Results");
		organel_mean_intensity = Table.getColumn("Mean","Results");
	}
	else{
		organel_areas = newArray(0);
		organel_mean_intensity = newArray(0);
	}
	// like in weighted averages:
	// cell_mean_intensity =  
	//	{[cell_area - sum(organel_areas)]*background_intensity + sum(organel_areas X organel_mean_intensity)} / cell_area
	// so one can extract background_intensity from it
	sum_organel_areas = 0;
	sum_organel_area_X_mean = 0;
	for(i=0;i<organel_areas.length;i++){
		sum_organel_areas += organel_areas[i];
		sum_organel_area_X_mean += organel_areas[i] * organel_mean_intensity[i];
	}
	background_intensity = ((cell_mean_intensity * cell_area) -  sum_organel_area_X_mean) / (cell_area - sum_organel_areas);
	//waitForUser("background_intensity: " + background_intensity);
	ClearRoiManager();
	roiManager("Open", tmpROIFullPath);
	return background_intensity;
	
}

function ClearRoiManager()
{
	roiManager("reset");
	/*if(roiManager("count") <= 0)
		return;
	roiManager("deselect");
	roiManager("delete");*/
}

function ErodeLabels(imageId)
{
	DoubleSelectImageId(imageId);
	// erode labels
	image1 = getTitle();
	Ext.CLIJ2_push(image1);
	image2 = image1+"_erode_labels";
	radius = 1.0;
	relabel_islands = false;
	Ext.CLIJ2_erodeLabels(image1, image2, radius, relabel_islands);
	Ext.CLIJ2_pull(image2);
	return DoubleGetImageId();
}


function GetLDsLabeledImage(imageId)
{
	//prepare image for strardist
	//gLDZimageId = DupSlice(imageId,gLDChannel, iLDSlice);

	gLDZimageId = DupChannelAndZProject(imageId,gLDChannel, "Max Intensity");

	//save rois and clear roi table	
	tmpROIFullPath = gImagesResultsSubFolder+"/"+"LD_"+gTempROIFile;
	roiNotEmpty = SaveROIs(tmpROIFullPath);
	//after saving rois clear roi table
	
	
	gLDsFilteredLabelsImageId = GetLDsRois();
	
	ClearRoiManager();
	
	if(roiNotEmpty){
		roiManager("Open", tmpROIFullPath);
	}
	
	return gLDsFilteredLabelsImageId;	
}


function ScaleImage(imageId, scaleFactor)
{
	s = "x="+scaleFactor
	+" y="+scaleFactor
	//+" width="+width*scaleFactor
	//+" height="+height*scaleFactor
	+" interpolation=None create";
	run("Scale...",s);
	return DoubleGetImageId();
}

function SaveROIs(fullPath)
{
	if(roiManager("count") <= 0)
		return false;
	roiManager("deselect");
	roiManager("save", fullPath);	
	return true;
}

function UsePrevRun(title,usePrevRun,restoreRois)
{
	if(!usePrevRun)
		return false;

	savePath = gImagesResultsSubFolder + "/"+gSaveRunDir+"/";
	labeledImageFullPath = savePath + title +".tif";
	labeledImageRoisFullPath = savePath + title +"_RoiSet.zip";

	if(!File.exists(labeledImageFullPath))
		return false;
	
	if(restoreRois && !File.exists(labeledImageRoisFullPath))
		return false;
		
	open(labeledImageFullPath);
	rename(title);
	id = DoubleGetImageId();
	if(restoreRois)
		openROIs(labeledImageRoisFullPath,true);
	DoubleSelectImageId(id);
	//print("Using stored "+title+" labeled image");
	return true;;
}


function StoreRun(title,storeROIs)
{
	//waitForUser("store title: "+title);
	savePath = gImagesResultsSubFolder + "/"+gSaveRunDir+"/";
	//waitForUser("store gImagesResultsSubFolder: "+gImagesResultsSubFolder);
	//waitForUser("store savePath: "+savePath);
	
	labeledImageFullPath = savePath + title +".tif";
	
	selectWindow(title);
	saveAs("Tiff", labeledImageFullPath);
	rename(title);
	if(storeROIs)
	{
		labeledImageRoisFullPath = savePath + title +"_RoiSet.zip";
		SaveROIs(labeledImageRoisFullPath);
	}
}

function RunStarDistModel(imageId)
{
	labelImageId = -1;


//	labeledImageFullPath = gImagesResultsSubFolder + "/" + StarDistWindowTitle +".tif";
//	labeledImageRoisFullPath = gImagesResultsSubFolder + "/" + StarDistWindowTitle +"_RoiSet.zip";

	if(UsePrevRun(gStarDistWindowTitle,false,true))
	{
		print("Using StarDist stored labeled image");
		labelImageId = DoubleGetImageId();
	}
	else 
	{
		starDistModel = "'Versatile (fluorescent nuclei)'";
		percentileBottom = 1.0;
		probThresh = 0.5;
		nmsThresh = 0.4;
		print("Progress Report: StarDist started. That might take a few minutes");

		DoubleSelectImageId(imageId);
		//rename("image for stardist");

		title = getTitle();
		run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=["
		+"'input':'"+title+"'"
		+", 'modelChoice':"+starDistModel
		+", 'normalizeInput':'true', 'percentileBottom':'" + percentileBottom + "'"
		+ ", 'percentileTop':'99.8'"
		+", 'probThresh':'"+probThresh+"'"
		+", 'nmsThresh':'"+nmsThresh+"'"
		+", 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");		

		labelImageId = DoubleGetImageId();
		StoreRun(gStarDistWindowTitle,true);
		print("Progress Report: StarDist ended.");	
		if(roiManager("count") <= 0)
		{
			print("WARNING!!!: Stardist did not identify any cell/object in " + title);
		}
		//print("num lds: "+roiManager("count"));
	}
	return labelImageId;
}
function RunIlastikModel(imageId)
{
	setBatchMode(false);
	DoubleSelectImageId(imageId);
	title = getTitle();
	found = false;
	IlastikSegmentationOutFile = title+gIlastikSegmentationExtention;
	IlastikOutFilePath = gImagesResultsSubFolder+"/"+gSaveRunDir+"/";

	if (!found)
	{
		if(!gInitiatedIlastik){
			run("Configure ilastik executable location", "executablefile=["+iIlastikExe+"] numthreads=-1 maxrammb=150000");
			gInitiatedIlastik = true;
		}
		print("Progress Report: Ilastik pixel classifier started. That might take a few minutes");	
		//run("Run Autocontext Prediction", "projectfilename=[A:\\yairbe\\Ilastic Training\\CreOFF-Axon-Classifier_v133post3.ilp] 
		//    inputimage=[A:\\yairbe\\Ilastic Training\\Cre off HD R.h5\\data] autocontextpredictiontype=Segmentation");
		run("Run Pixel Classification Prediction", "projectfilename=["+iIlastikModelPath+"] inputimage=["+title+"] pixelclassificationtype=Segmentation");
		
		//rename("Segmentation");
		rename(IlastikSegmentationOutFile);
		//waitForUser("check ilastik output");
		// save Ilastik Output File
		selectWindow(IlastikSegmentationOutFile);
		print("Saving Ilastik autocontext classifier output...");
		//run("Export HDF5", "select=["+resFolder+IlastikProbOutFile1+"] exportpath=["+resFolder+IlastikProbOutFile1+"] datasetname=data compressionlevel=0 input=["+IlastikProbOutFile1+"]");	
		run("Export HDF5", "select=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] exportpath=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] datasetname=data compressionlevel=0 input=["+IlastikSegmentationOutFile+"]");	
		print("Progress Report: Ilastik ended.");	
	}	
	rename(IlastikSegmentationOutFile);
	//setVoxelSize(width, height, depth, unit); multiplying area size instead
	setBatchMode(gBatchModeFlag);
	return DoubleGetImageId();
}

function RunCellposeModel(imageId)
{
	if(iUseExternalCellposeRun)
	{
		labeledImageFullPath = File.getDirectory(gFileFullPath)+File.separator +iMitoCellposeExtRunDir+gFileNameNoExt+iCellposeExtRunFileSuffix;
		if(File.exists(labeledImageFullPath)){
			print("Using external cell segmentation label file: "+labeledImageFullPath);
			open(labeledImageFullPath);
			return DoubleGetImageId();
		}
		else{
			print("External cell segmentation label file not found: "+labeledImageFullPath);			
		}
	}
	labelImageId =  RunCellpose_LSCF(imageId, iMitoCellposeModelPath, iMitoCellposeCellDiameter, 1, 2, "--use_gpu", iCellposeEnv);
	return labelImageId;
}


function GenerateROIsFromLabelImage(labelImageId,type,filterMinAreaSize)
{
	nBefore = roiManager("count");
	DoubleSelectImageId(labelImageId);
	run("Label image to ROIs");
	nAfter = roiManager("count");
	if(filterMinAreaSize > 0)
	{
		run("Clear Results");
		roiManager("deselect");
		roiManager("measure");
		for(i=nAfter-1;i>=nBefore;i--)
		{
			area = Table.get("Area",i, "Results");
			if(area < filterMinAreaSize)
			{
				roiManager("select", i);
				roiManager("delete");
				nAfter--;
			}
		}
	}
	if(type != "")
	{
		for(i=nBefore;i<nAfter;i++)
		{
			roiManager("deselect");
			roiManager("select", i);
			str = type+"_"+(i-nBefore+1);
			roiManager("rename",str);

		}
	}
	return nAfter - nBefore;
}
function DupChannelAndZProject(imageId, channel, projectionType)
{
	DoubleSelectImageId(imageId);
	//1. prepare image for Cellpose: duplicate the 3rd channel and z-project it
	run("Duplicate...", "duplicate channels="+channel);
	run("Z Project...", "projection=["+projectionType+"]"); //Max Intensity
	return DoubleGetImageId();	
}

function DupSlice(imageId, channel, slice)
{
	DoubleSelectImageId(imageId);
	//1. prepare image for ilastik: duplicate the 3rd channel and 4th slice in it
	run("Duplicate...", "duplicate channels="+channel+" slices="+slice);
	return DoubleGetImageId();	
}


//if file exists, add the rois to the end of it otherwise creates it
function AppendRois(full_path){
	if(File.exists(full_path)){
		n = roiManager("count");
		roiManager("open", full_path);
		nn = roiManager("count");
		SaveROIs(full_path);
		for(i=nn-1;i>=n;i--){
			roiManager("select",i);
			roiManager("delete");
		}
	}
	else{
		SaveROIs(full_path);
	}
		
}




function RunThreshold(from, to)
{
	//run("Threshold...");
	setThreshold(from, to, "raw");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	return DoubleGetImageId();
}


function GetRoiArea(roiIndex)
{
	roiManager("Select", roiIndex);
	run("Clear Results");
	run("Set Measurements...", "area shape integrated display redirect=None decimal=3");
	run("Measure");
	area = Table.get("Area",0, "Results");
	return area;	
}


function dupChannel(imageId,channel,newTitle)
{
	DoubleSelectImageId(imageId);
	run("Select None");
	roiManager("deselect");
	run("Duplicate...", "title=["+newTitle+"] duplicate channels="+channel);
	return DoubleGetImageId();
}


function selectLastROI()
{
	n = roiManager("count");
	roiManager("Select", n-1);
}











function FinalActions()
{
	//waitForUser("here?: "+gMainDirectory);
	if(gAllCompositeResults > 0){ // stroe allCompositeTable table
		Table.save(gResultsSubFolder+"/"+gAllCompositeTable+".csv", gAllCompositeTable);
		CloseTable(gAllCompositeTable);
	}
	//waitForUser("not here?");
}
// end of single file analysis

//--------Helper functions-------------

function Initialization()
{
	requires("1.53c");
	run("Check Required Update Sites");
	// for CLIJ
	run("CLIJ2 Macro Extensions", "cl_device=");
	Ext.CLIJ2_clear();


	//run("Configure ilastik executable location", "executablefile=["+iIlastikExe+"] numthreads=-1 maxrammb=150000");
	//run("Cellpose setup...", "cellposeenvdirectory="+iCellposeEnv+" envtype=conda usegpu=true usemxnet=false usefastmode=false useresample=false version=2.0");		
	
	setBatchMode(false);
	run("Close All");
	close("\\Others");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area mean standard perimeter fit shape median display redirect=None decimal=3");
	roiManager("Reset");

	CloseTable("Results");
	CloseTable(gCompositeTable);	
	CloseTable(gAllCompositeTable);

	run("Collect Garbage");

	if (gBatchModeFlag)
	{
		print("Working in Batch Mode, processing without opening images");
		setBatchMode(gBatchModeFlag);
	}	

}

function checkInput()
{
	getDimensions (ImageWidth, ImageHeight, ImageChannels, ImageSlices, ImageFrames);

	if(ImageChannels < 3)
	{
		print("Fatal error: input file must include 3 channels: Lipid Droplets, Litosomes, and Mitocondria stainings");
		return false;
	}
	getPixelSize(unit,pixelWidth, pixelHeight);
	if(!matches(unit, "microns") && !matches(unit, "um"))
	{
		print("Fatal error. File " + gFileFullPath + " units are "+ unit+ " and not microns");
		return false;
	}
	return true;
}
//------openROIsFile----------
//open ROI file with 
function openROIsFile(ROIsFileNameNoExt, clearROIs)
{
	roiManager("deselect");
	// first delete all ROIs from ROI manager
	if(clearROIs && roiManager("count")
		roiManager("delete");

	// ROIs are stored in "roi" suffix in case of a single roi and in "zip" suffix in case of multiple ROIs
	RoiFileName = ROIsFileNameNoExt+".roi";
	ZipRoiFileName = ROIsFileNameNoExt+".zip";
	if (File.exists(RoiFileName) && File.exists(ZipRoiFileName))
	{
		if(File.dateLastModified(RoiFileName) > File.dateLastModified(ZipRoiFileName))
			roiManager("Open", RoiFileName);
		else
			roiManager("Open", ZipRoiFileName);
		return true;
	}
	if (File.exists(RoiFileName))
	{
		roiManager("Open", RoiFileName);
		return true;
	}
	if (File.exists(ZipRoiFileName))
	{
		roiManager("Open", ZipRoiFileName);
		return true;
	}
	return false;
}

function openROIs(ROIsFullName, clearROIs)
{
	roiManager("deselect");
	// first delete all ROIs from ROI manager
	if(clearROIs && roiManager("count") > 0)
		roiManager("delete");

	if (File.exists(ROIsFullName))
	{
		roiManager("Open", ROIsFullName);
		return true;
	}
	return false;
}
function openFile(fileFullPath)
{
	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	if ( endsWith(fileFullPath, "h5") )
		run("Import HDF5", "select=["+fileFullPath+"] "+ gH5OpenParms);
	else if ( endsWith(fileFullPath, "ims") )
		run("Bio-Formats Importer", "open=["+fileFullPath+"] "+ gImsOpenParms);
	else if ( endsWith(fileFullPath, "nd2") )
		run("Bio-Formats Importer", "open=["+fileFullPath+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	else
		open(fileFullPath);

	return checkInput();
	
}


//----------LoopFiles-------------
// according to iProcessMode analyzes a single file, or loops over a directory or sub-directories
function LoopFiles()
{
	SetProcessMode();
	if (matches(iProcessMode, "AllSubFolders")) {
		return LoopFolders(gMainDirectory);
	}
	
	gResultsSubFolder = gMainDirectory + File.separator + "Results" + File.separator; 
	File.makeDirectory(gResultsSubFolder);
	SaveParms(gResultsSubFolder);
	

	print("directory: "+ gMainDirectory);
	
	if (matches(iProcessMode, "singleFile")) {
		return ProcessFile(gMainDirectory); 
	}
	else if (matches(iProcessMode, "wholeFolder")) {
		return ProcessFiles(gMainDirectory); 
	}

	return true;
}
function LoopFolders(mainDir){
	gResultsSubFolder =  mainDir + File.separator + "Results" + File.separator; 
	gMainDirectory = mainDir;
	if(!ProcessFiles(mainDir))
		return false;
	list = getFileList(mainDir);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(mainDir + "/" + list[i])) {
			gSubFolderName = mainDir + "/" + list[i];
			if(!LoopFolders(gSubFolderName))
				return false;
		}
	}
	//waitForUser("mainDir: "+mainDir);
	print("Processing "+mainDir+ " Done");
	return true;
}
function SaveParms(resFolder)
{
	//waitForUser("macro"+File.getNameWithoutExtension(getInfo("macro.filepath")));
	// print parameters to Prm file for documentation
	PrmFile = pMacroName+"Parameters.txt";
	if(iProcessMode == "singleFile")
		PrmFile = resFolder + File.getNameWithoutExtension(gFileFullPath) + "_" + PrmFile;
	else 
		PrmFile = resFolder + PrmFile;
		
	File.saveString("macroVersion="+pMacroVersion, PrmFile);
	File.append("", PrmFile); 
	
	File.append("RunTime="+getTimeString(), PrmFile);
	
	// save user input
	File.append("Process mode="+iProcessMode, PrmFile); 
	File.append("File extention="+ iFileExtension, PrmFile); 
	File.append("Ilastik Executable="+iIlastikExe+" \n", PrmFile); 
	File.append("Ilastik Model Path="+iIlastikModelPath, PrmFile);
	File.append("Mito min size="+iMitoMinSize, PrmFile);
	File.append("Mito Max Fregmented="+iMitoMaxFregmented, PrmFile);
	File.append("Mito Min Elongated="+iMitoMinElongated, PrmFile);
	File.append("Mito Min hyper Elongated="+iMitoMinHyperElongated, PrmFile);
	File.append("Mito slice="+iMitoSlice, PrmFile);
	File.append("Background Substractor="+iBackgroundSubstractor, PrmFile);
	File.append("LD Intensity Threshold="+iLDIntensityThreshold, PrmFile);
	File.append("LD Max size="+iLDMaxSize, PrmFile);
	File.append("Cellpose Model Path="+iMitoCellposeModelPath, PrmFile);
	File.append("Cellpose Cell Diameter="+iMitoCellposeCellDiameter, PrmFile);
	File.append("Cellpose External Run Directory="+iMitoCellposeExtRunDir, PrmFile);
 	File.append("Cell min. size="+iMinCellAreaSize, PrmFile);
	File.append("Cell dilation size (Pixels)="+iDilationSize, PrmFile);
	File.append("LD Channel="+gLDChannel, PrmFile);
	File.append("Mitochondria Channel="+gMitoChannel, PrmFile);
	File.append("Dapi Channel="+gDapiChannel, PrmFile);
 	
 	File.append("LD cluster Distance="+iLDclusterDistance, PrmFile);
 	File.append("LD cluster min Density="+iLDminDensity, PrmFile);

File.append("Ilastik, executable="+iIlastikExe, PrmFile);
File.append("Cellpose, Enviorenment="+iCellposeEnv, PrmFile);
File.append("Use external run for cell segmentation="+iUseExternalCellposeRun, PrmFile);
File.append("Cell segmentation External run sub-directory="+iMitoCellposeExtRunDir, PrmFile);
File.append("Cell segmentation file name suffix="+iCellposeExtRunFileSuffix, PrmFile);






}
function getTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
	return TimeString;
}
//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory) 
{
	Table.create(gAllCompositeTable);		
	gAllCompositeResults = 0;

	setBatchMode(gBatchModeFlag);
	dir1=substring(directory, 0,lengthOf(directory)-1);
	idx=lastIndexOf(dir1,File.separator);
	subdir=substring(dir1, idx+1,lengthOf(dir1));

	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], iFileExtension) ) {
			gFileFullPath = directory+File.separator+fileListArray[fileIndex];
			print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			if(!ProcessFile(directory))
				return false;
			CleanUp(false);		
		} // end of if 
	} // end of for loop
	FinalActions();
	CleanUp(true);
	return true;
} // end of ProcessFiles

function CleanUp(finalCleanUp)
{
	run("Close All");
	close("\\Others");
	run("Collect Garbage");
	if (finalCleanUp) 
	{
		CloseTable(gAllCompositeTable);	
		setBatchMode(false);
	}
}
function SetProcessMode()
{
		// Choose image file or folder
	if (matches(iProcessMode, "singleFile")) {
		gFileFullPath=File.openDialog("Please select an image file to analyze");
		gMainDirectory = File.getParent(gFileFullPath);
	}
	else if (matches(iProcessMode, "wholeFolder")) {
		gMainDirectory = getDirectory("Please select a folder of images to analyze"); }
	
	else if (matches(iProcessMode, "AllSubFolders")) {
		gMainDirectory = getDirectory("Please select a Parent Folder of subfolders to analyze"); }
}

//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}

//assumes each ROI has a different label
//
//1. At first it removes all overlaps between original rois in the following way:
//	1.1. If one roi is competely contained in another it removes it
//2. Then it enlarges the rois in the order they appear in the roi manager (so in case of competition the smaller index wins)


function EnlargeRoiNoOverlaps(roi_ind, size){
	n = roiManager("count");
	run("Select None");
	roiManager("deselect");
	roiManager("select", roi_ind);
	iLabel = Roi.getName; // keep the roi label
	run("Enlarge...", "enlarge="+size+" pixel"); // enlarge the roi
	roiManager("Update");
	roiLabels = GetRoiLabels();
	// look for overlaps with all other rois
	for(k=0;k<n;k++){
		current_i = GetRoiByLabel(iLabel);	
		jLabel = roiLabels[k];
		j = GetRoiByLabel(jLabel);
		if(j == current_i){
			continue;
		}
		roiManager("Select", newArray(j,current_i));
		roiManager("AND");
		if(selectionType() >= 0){
			roiManager("Add"); // add the overlap area as separate roi
			roiManager("Select", newArray(current_i,n));
			roiManager("XOR");
			if(selectionType() >= 0){
				roiManager("Add");
				roiManager("delete"); // delete the original roi and the overlap roi
				roiManager("select", n-1);
				roiManager("rename", iLabel);
			}
			else{
				roiManager("select", n);
				roiManager("delete");
			}
		}
	}
}

function RemoveRoiOverlaps(roi_ind){
	n = roiManager("count");
	roiManager("Select",roi_ind);
	iLabel = Roi.getName;

	roiLabels = GetRoiLabels();

	for(k=0;k<n;k++){
		current_i = GetRoiByLabel(iLabel);	
		jLabel = roiLabels[k];
		j = GetRoiByLabel(jLabel);
		if(j == current_i){
			continue;
		}
		roiManager("Select", newArray(j,current_i));
		roiManager("AND");
		if(selectionType() >= 0){
			roiManager("Add"); // add the overlap area as separate roi
			Roi.getContainedPoints(andXpoints, andYpoints);
			
			roiManager("Select",j);
			Roi.getContainedPoints(jXpoints, jYpoints);
			//waitForUser("jXpoints.length="+jXpoints.length+", andXpoints.length="+andXpoints.length);
			if(jXpoints.length == andXpoints.length){
				print("Warning: "+jLabel+" is contained in "+ iLabel + " and is removed");
				//waitForUser("j="+j+", n="+n);
				roiManager("Select", newArray(j,n));	
				roiManager("delete");

				continue;
			}			
			roiManager("Select",current_i);
			Roi.getContainedPoints(iXpoints, iYpoints);
			if(iXpoints.length == andXpoints.length){
				print("Warning: "+iLabel+" is contained in "+ jLabel + " and is removed");
				roiManager("Select", newArray(current_i,n));				
				roiManager("delete");
				return;
			}
			// remove the overlap from the larger roi	
			smallInd = j;
			bigInd = current_i;	
			savedLabel = iLabel;		
			if(iXpoints.length < jXpoints.length){
				smallInd = current_i;
				bigInd = j;		
				savedLabel = jLabel;
			}			
			roiManager("Select", newArray(bigInd,n));
			roiManager("XOR");
			if(selectionType() >= 0){
				roiManager("Add"); // add the roi without the overlap
				roiManager("delete"); // delete the original roi and the overlap roi
				roiManager("select", n-1);
				roiManager("rename", savedLabel);
			}
			else{
				roiManager("select", n);
				roiManager("delete"); // delete the overlap roi
			}
		}
	}
}

function EnlargeAllRoisNoOverlaps(size){
	RemoveAllRoisOverlaps();
	n = roiManager("count");
	roiLabels = GetRoiLabels();
	for(i=n-1;i>=0;i--){
		roi_ind = GetRoiByLabel(roiLabels[i]);
		EnlargeRoiNoOverlaps(roi_ind, size);
	}
}

function GetRoiLabels(){
	n = roiManager("count");
	roiLabels = newArray(n);
	for(i=0;i<n;i++){
		roiManager("select", i);
		roiLabels[i] = Roi.getName;
	}
	return roiLabels;
}

function RemoveAllRoisOverlaps(){
	n = roiManager("count");
	roiLabels = GetRoiLabels();
	for(i=0;i<n;i++){
		roi_ind = GetRoiByLabel(roiLabels[i]);
		if(roi_ind > 0){
			RemoveRoiOverlaps(roi_ind);
		}
	}
}

function GetRoiByLabel(label){
	n = roiManager("count");
	for(i=0;i<n;i++){
		roiManager("select", i);
		if(Roi.getName == label)
			return i;
	}
	print("Warning: roi label " + label + " not found");
	return -1;
}

function DoubleSelectImageId(id){
	wait(2);
	selectImage(id);
	wait(2);
	selectImage(id);
}

function DoubleGetImageId(){
	//wait(2);
	//getImageID();
	//wait(2);
	id = getImageID();
	return id;
}
