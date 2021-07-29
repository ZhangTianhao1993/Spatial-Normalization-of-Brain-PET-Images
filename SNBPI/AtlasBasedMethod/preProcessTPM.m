function [pTPM,mask] = preProcessTPM(TPM,x,y,z)
% preprocess TPM images

TPM(isnan(TPM))=0;

[~,~,~,n] = size(TPM);
pTPM = zeros(x,y,z,n);
for i=1:n
    t = squeeze(TPM(:,:,:,i));
    pTPM(:,:,:,i) = resize3D(t,x,y,z);
end

pTPM(pTPM<0)=0;

mask = sum(pTPM,4);

pTPM = reshape(pTPM,[],n);
pTPM = sparse(pTPM);

