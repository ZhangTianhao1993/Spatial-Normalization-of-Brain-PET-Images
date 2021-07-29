function [pTPM,mask] = preProcessTPM(TPM,x,y,z)
% 去掉nan
TPM(isnan(TPM))=0;
% 缩放TPM，和图像缩放一致
[~,~,~,n] = size(TPM);
pTPM = zeros(x,y,z,n);
for i=1:n
    t = squeeze(TPM(:,:,:,i));
    pTPM(:,:,:,i) = resize3D(t,x,y,z);
end
%保证非负
pTPM(pTPM<0)=0;

mask = sum(pTPM,4);

%稀疏化
pTPM = reshape(pTPM,[],n);
pTPM = sparse(pTPM);

