function newTPM = mergeTPM(TPM,maxIndexList,BIClist)
[x,y,z,L] = size(TPM);
tTPM = TPM;
n = length(BIClist)-find(BIClist == min(BIClist))+1;
for i=1:L-n
    maxIndex = maxIndexList(i,:);
    tTPM(:,:,:,maxIndex(1)) = tTPM(:,:,:,maxIndex(1))+tTPM(:,:,:,maxIndex(2));
    tTPM(:,:,:,maxIndex(2)) = [];
end
newTPM = tTPM;
end