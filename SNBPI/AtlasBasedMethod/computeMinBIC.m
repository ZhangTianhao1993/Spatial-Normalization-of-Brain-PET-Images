function [BIClist,maxIndexList] = computeMinBIC(pwImg,psTPM,regularterm)
% 用贪婪算法合并组织概率图，找到最佳的合并方案
% BIClist记录每一种脑区划分方式得到的BIC
% maxIndexList记录脑区的合并方式
[~,n] = size(psTPM);
BIClist = zeros(n,1);
maxIndexList = zeros(n-1,2);
for i=1:n
   BIClist(i) = computeBIC(pwImg,psTPM,regularterm);
   if i<n
       [psTPM,maxIndexList(i,:)] = fusionTPM(pwImg,psTPM); %合并一次标签,得到新的TPM
   end
  % fprintf('%d\n',i);
end
%figure;
%plot(n:-1:1,BIClist);