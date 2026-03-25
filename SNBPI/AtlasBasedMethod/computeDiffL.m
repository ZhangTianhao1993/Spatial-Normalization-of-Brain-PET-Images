function diffL = computeDiffL(pwImg,psTPM,i,j,baselineLogL)
% Given two ROI indexes, calculate the size of the log-likelihood change 
% before and  after the merger
% Input:
% pwImg - preprocessed and spatial normalized image
% psTPM - preprocessed and shrunken TPM images
% i,j   - ROI index
% Output:
% diffL - the size of change before and after the merger
% Author: ZhangTianhao, 2021/7/29
% =========================================================================
newTPM = psTPM;
newTPM(:,i) = psTPM(:,i)+psTPM(:,j);
newTPM(:,j) = [];
diffL = computeLogLikelihood(pwImg,newTPM)-baselineLogL;