#@ File(label="Input directory",value="", style="directory", persist=true) iInDir
#@ File(label="Output directory",value="", style="directory", persist=true) iOutDir
#@ Boolean(label="Handle subdirectories", persist=true) iHandleSubDirs
#@ String(label="File Extension",value=".nd2", persist=true, description="eg .tif, .nd2") iFileExtension
#@ String(label="Main channel",value="2", persist=true, ) iChannel1
#@ String(label="Additional (Nuclei) channel (0 for none)",value="1", persist=true, ) iChannel2
#@ Boolean(label="Z project (y/n)",value=true, persist=true, description="Combine Z slices to one") iZproject
#@ String(label="Z projection type ",value="Max Intensity", persist=true, ) iZprojectionType






//macro that prepares a directory with tiff files for Cellpose
//The first channel is the main segmentation channel
//If both cytoplasm and nuclei channels exist in the original file, then the nuclei will be added as an additional channel
//In case the origianl file has Z slices - it is combine to one in the output tif file

var gFileFullPath = "unintialized";
//var gMainDirectory = "unintialized";
//var gOutDirectory = "uninitialized";	   // input  directory for cellpose batch processing
//gMainDirectory = iInDir; //getDirectory("Please select a folder of images to prepare for Cellpose segmentation"); // added by OG
//gOutDirectory = iOutDir; //gMainDirectory + "/"+iSubDir; // added by OG
MakeDirRecursive(iOutDir);
//File.makeDirectory(gOutDirectory);
//File.makeDirectory(gOutDirectory+"/Segmentation"); // output directory for cellpose batch processing

//-----debug variables--------
var gDebugFlag = false;
var gBatchModeFlag = true;
//var gBatchModeFlag = false;
//-----------

if(ProcessFiles(iInDir, iOutDir))
	print("Macro ended successfully");
else
	print("Macro failed");
CleanUp();
waitForUser("=================== Done ! ===================");
function ProcessFile(outDir) 
{
	setBatchMode(gBatchModeFlag);
	
//print("In ProcessFile: ", gFileFullPath);
	if(!openFile(gFileFullPath))
		return false;
		
	gFileNameNoExt = File.getNameWithoutExtension(gFileFullPath);

	//run("Duplicate...", "title=d1 duplicate");
	channels = ""+iChannel1;
	if(iChannel2 > 0)
		channels += iChannel2;
	run("Arrange Channels...", "new="+channels);
	imageTitle = getTitle();

	run("Z Project...", "projection=["+iZprojectionType+"]");
	imageTitle = getTitle();


	saveAs("Tiff",outDir+"/"+gFileNameNoExt+".tif");
	return true;
}


//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(inDir, outDir) 
{
	//getDirectory("Please select a folder of images to prepare for Cellpose segmentation"); // commented by OG

	setBatchMode(gBatchModeFlag);
	// Get the files in the folder 
	fileListArray = getFileList(inDir);
	
//print("in ProcessFiles, nFiles = ", lengthOf(fileListArray));
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], iFileExtension) ) {
			gFileFullPath = inDir+File.separator+fileListArray[fileIndex];
			print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			if(!ProcessFile(outDir))
				return false;
		} // end of if 
		else if(iHandleSubDirs){
			if(File.isDirectory(inDir+ "/" + fileListArray[fileIndex])){
				if(!File.exists(outDir+ "/" + fileListArray[fileIndex])){
					File.makeDirectory(outDir+ "/" + fileListArray[fileIndex]);
				}
				ProcessFiles(inDir+ "/" + fileListArray[fileIndex], outDir+ "/" + fileListArray[fileIndex]);
			}
		}
	} // end of for loop
	return true;
} // end of ProcessFiles

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
	if ( endsWith(gFileFullPath, "h5") )
		run("Import HDF5", "select=["+gFileFullPath+"] "+ gH5OpenParms);
	else if ( endsWith(gFileFullPath, "ims") )
		run("Bio-Formats Importer", "open=["+gFileFullPath+"] "+ gImsOpenParms);
	else if ( endsWith(gFileFullPath, "nd2") || endsWith(gFileFullPath, "czi"))
		run("Bio-Formats Importer", "open=["+gFileFullPath+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	else
		open(gFileFullPath);
	

	return checkInput();
	
}

function checkInput()
{
	getDimensions (ImageWidth, ImageHeight, ImageChannels, ImageSlices, ImageFrames);
//	print("ImageWidth: "+ImageWidth+", ImageHeight: "+ImageHeight+", ImageChannels: " +ImageChannels+", ImageSlices: " + ImageSlices+", ImageFrames: "+ImageFrames);

	if(ImageChannels <  iChannel1 || ImageChannels <  iChannel2)
	{
		print("Fatal error: num channels in image is less than specified channels");
		return false;
	}
	
	if(iChannel1 == 0)
	{
		print("Fatal error: channel1 cannot be 0");
		return false;
	}	
	return true;
}

function MakeDirRecursive(path){
	dirs = split(path,"\\/");
	sub_path = dirs[0];
	for(i=1;i<dirs.length;i++){
		if(String.trim(dirs[i].length) > 0){
			sub_path += "/"+ dirs[i];
			if(!File.exists(sub_path)){
				File.makeDirectory(sub_path);
			}
		}
	}
}
