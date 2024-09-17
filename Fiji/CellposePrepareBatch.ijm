//macro that prepares a directory with tiff files for Cellpose
//The first channel is the main segmentation channel
//If both cytoplasm and nuclei channels exist in the original file, then the nuclei will be added as an additional channel
//In case the origianl file has Z slices - it is combine to one in the output tif file

#@ File (label = "Input directory", style = "directory", persist=true) iInDir
#@ Boolean(label="Process sub directories (y/n)",value=true, persist=true, description="Generate Z images in sub directories as well") iRecursive

#@ String(label="File Extension",value=".nd2", persist=true, description="eg .tif, .nd2") iFileExtension
#@ String(label="Main channel",value="2", persist=true, ) iChannel1
#@ String(label="Additional (Nuclei) channel (0 for none)",value="1", persist=true, ) iChannel2
#@ String(label="Sub Folder",value="Max Intensity", persist=true, ) iSubDir
#@ Boolean(label="Z project/Specific slice (y/n)",value=true, persist=true, description="Combine Z slices to one") iZproject
#@ String(label="Z projection type/Slice number ",value="Max Intensity", persist=true, ) iZprojectionType_OR_slice
#@ Boolean(label="Prepare cellpose batch command (y/n)",value=true, persist=true, description="CellposeBatchCommand.txt file is stored in the sub directory") iPrepareBatchCommand
#@ String(label="Fill the following parameters only if cellpose batch command is wanted!!!!!!!!!!!",value="-----------------------", persist=false, ) iIgnore
#@ String(label="Cellpose segmentation sub-directory ",value="Segmentation", persist=true, ) iCellposeSubDir
#@ String(label="Cellpose model",value="Cyto3", persist=true, ) iCellposeModel
#@ String(label="Cell diameter",value="5", persist=true, ) iCellDiameter
#@ Boolean(label="Discard masks which touch edges of image",value=false, persist=true, description="Combine Z slices to one") iExcludeOnEdges




var gOutDirectory = "uninitialized";	   // input  directory for cellpose batch processing
var gImsOpenParms = "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_1"; //bioImage importer auto-selection

//-----debug variables--------
var gDebugFlag = false;
var gBatchModeFlag = true;
//var gBatchModeFlag = false;
//-----------

//var gCellposeBatchPath = iInDir + "/" + iSubDir + "/" + "CellposeBatchCommands.txt";

//File.saveString("mkdir \""+iInDir + "/" + iSubDir+"\"", gCellposeBatchPath);

setBatchMode(gBatchModeFlag);
if(processFolder(iInDir))
	print("Macro ended successfully");
else
	print("Macro failed, see log for details");
	
CleanUp();
waitForUser("=================== Done ! ===================");
// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]) && iRecursive)
			if(!processFolder(input + File.separator + list[i])){
				return false;
			}
		if(endsWith(list[i], iFileExtension)){
			return ProcessFiles(input, list);
		}
	}
	return true;
}

function ProcessFile(directory, fileName) 
{
	close("*");
	fileFullPath = directory + File.separator + fileName;
	print("In ProcessFile: ", fileFullPath);
	openFile(fileFullPath);
		
	channels = ""+iChannel1;
	if(iChannel2 > 0)
		channels += iChannel2;
	run("Arrange Channels...", "new="+channels);
	if(iZproject){
		run("Z Project...", "projection=["+iZprojectionType_OR_slice+"]");
	}
	else{
		run("Make Substack...", "  slices="+iZprojectionType_OR_slice);
	}
	fileNameNoExt = File.getNameWithoutExtension(fileFullPath);
	saveAs("Tiff",gOutDirectory+"/"+fileNameNoExt+".tif");
	return true;
}


//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory, fileListArray) 
{
	gOutDirectory = directory + "/"+iSubDir; 	
	File.makeDirectory(gOutDirectory);

	//getDirectory("Please select a folder of images to prepare for Cellpose segmentation"); // commented by OG

	setBatchMode(gBatchModeFlag);
	// Get the files in the folder 
	
//print("in ProcessFiles, nFiles = ", lengthOf(fileListArray));
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], iFileExtension) ) {
			if(!ProcessFile(directory, fileListArray[fileIndex]))
				return false;
		} // end of if 
	} // end of for loop
	
	if(iPrepareBatchCommand){
		cellposeOutDir = gOutDirectory+File.separator+iCellposeSubDir;
		File.makeDirectory(cellposeOutDir);
		str = PrepareCellposeBatchCommand(gOutDirectory, cellposeOutDir, iCellposeModel, iChannel1, iChannel2, iCellDiameter, iExcludeOnEdges);
		File.saveString(str, gOutDirectory+File.separator + "CellposeBatchCommand.txt");
	}
	return true;
} // end of ProcessFiles

function PrepareCellposeBatchCommand(cellposeInDir, cellposeOutDir, cellposeModel, chan, chan2, cellDiameter, excludeOnEdges){
	str = "python -m cellpose --dir \""+cellposeInDir+"\" –-savedir \""+cellposeOutDir+"\" --pretrained_model "+cellposeModel+" --chan "+chan+" --chan2 "+chan2+" --diameter "+cellDiameter;
	if(excludeOnEdges){
		str += " --exclude_on_edges ";
	}
	str += " --no_npy --save_tif --use_gpu –-verbose";
	return str;
}
function CleanUp()
{
	run("Close All");
	close("\\Others");
	run("Collect Garbage");
	setBatchMode(false);
}

function openFile(fileName)
{
	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	if ( endsWith(fileName, "h5") ){
		run("Import HDF5", "select=["+fileName+"] "+ gH5OpenParms);
	}
	else if ( endsWith(fileName, "ims") ){
		run("Bio-Formats Importer", "open=["+fileName+"] "+ gImsOpenParms);
	}
	else if ( endsWith(fileName, "nd2") ){
		run("Bio-Formats Importer", "open=["+fileName+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	}
	else{
		open(fileName);
	}
}