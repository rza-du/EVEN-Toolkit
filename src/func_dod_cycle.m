function [subdegrade] = func_dod_cycle(INPUT)
%this function is used for generating subdegradation given the range and
%cycle
%   INPUT(:,1)---> lower limit of the range
%   INPUT(:,2)---> upper limit of the range
%   INPUT(:,3)---> number of cycles in the given range
%%
% a=512.2;  b=-1.9928;  % the two parameters are took from M J E Alam's study

% a=1500;  b=-1.683;  % the two parameters are took from M J E Alam's study, revised abit
a=2873.1;  b=-1.483;  % the two parameters are took from M J E Alam's study
% a=2873.1;  b=-1.683;  % the two parameters are took from M J E Alam's study

% a=383.1828; b=-1.9928;  % https://www.mpoweruk.com/life.htm
% a=1000.1828; b=-1.9928;  %%%%%%% https://www.mpoweruk.com/life.htm

% a=800; b=-1;   % refer to LEAD ACID BATTERY working
% a=1253.4;  b=-0.805;  % refer to 'LEAD ACID BATTERY working LIFETIME STUDY'
% a=5125;  b=-0.705;  % refer to 'LEAD ACID BATTERY working LIFETIME STUDY'

% 
% xx=0:0.05:1;
% yy=a*power(xx,b);
% % 
% figure; semilogy(xx,yy);
% INPUT=RangeCycle_i;
%%
% Used in previous paper
subdegrade=INPUT(:,3)/a./power(mean([INPUT(:,1),INPUT(:,2)],2),b);

% Used in the EVEN paper
% subdegrade=INPUT(:,3)./min(f_Curve_relation(100*mean([INPUT(:,1),INPUT(:,2)],2)),100000000);
end
