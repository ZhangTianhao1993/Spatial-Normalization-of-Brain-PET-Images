function [BIClist,maxIndexList] = computeMinBIC(pwImg,psTPM,regularterm)
% Use the greedy algorithm to merge the organization probability mapping to
% find the best way to merge
% Input:
% pwImg        - Preprocessed and spatial normalized image 
% psTPM        - Preprocessed and shrunken TPM images
% regularterm  - Regular term
% Output:
% BIClist      - Record each BIC obtained by fusion the brain region
% maxIndexList - Record the merging method
% Author: Zhang Tianhao, 2021/7/29
% =========================================================================

[~,n] = size(psTPM);
BIClist = zeros(n,1);
maxIndexList = zeros(n-1,2);
for i=1:n
   BIClist(i) = computeBIC(pwImg,psTPM,regularterm);
   if i<n
       [psTPM,maxIndexList(i,:)] = fusionTPM(pwImg,psTPM); 
   end
  % fprintf('%d\n',i);
end