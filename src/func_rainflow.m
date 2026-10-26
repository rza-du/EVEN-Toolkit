function [BIG] = func_rainflow(y)

% output is a matrix (13 rows * 10 comums) each row is a interval of range change, each column is a parametes, the mean of each column is shown below
%       BIG(i,1)=L(j);  lower limit of the range
%       BIG(i,2)=L(j+1);   upper limit of the range
%       BIG(i,3)=C(j);    number of cycles
%       BIG(i,4)=AverageAmp(j);
%       BIG(i,5)=MaxAmp(j);
%       BIG(i,6)=MinMean(j);      
%       BIG(i,7)=AverageMean(j);
%       BIG(i,8)=MaxMean(j);   
%       BIG(i,9)=MinValley(j); 
%       BIG(i,10)=MaxPeak(j);   
% focus on the beging three parameters

m=length(y)-1;
%a=zeros(m,1);     % the value of remaining data
%t=zeros(m,1);    % the number of teh data 1,2,3,...
a=[]; t=[];
a(1)=y(1);
t(1)=1;
k=2;

% Begin slope calculation
slope1=(y(2)-y(1));
for i=2:m        % this circulation detelets the points at which the positive/negative of scope does not change
     slope2=(y(i+1)-y(i));
     if((slope1*slope2)<=0)    
          a(k)=y(i);
          t(k)=i;
          k=k+1;      % reduce the number of point from length(y) to k
     end
     slope1=slope2;
end
%
a(k)=y(m+1);
t(k)=t(k-1)+1;
k=k+1;
%  End slope calculation

sza=size(a);
if(sza(2)>sza(1))
    a=a';
end
szt=size(t);
if(szt(2)>szt(1))
    t=t';
end
%
aa=[t a];  cc=a;  n=1; i=1; j=2;
%
aamax=0;
B=zeros(m,4);
a_mean=zeros(m,2);
kv=1;
msa_orig=max(size(aa));

%% #### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
while(1)
    msa=max(size(aa));     % because in the later calculation, every circle the first row of aa is deleted, so here checking the size of aa is needed.
    %@@@@@@@@@@@@@@@@@@
    if((j+1)>msa)      % these two sentences judge when the circulation stops (1)
        break;
    end
    if((i+1)>=msa)     % these two sentences judge when the circulation stops (2)
        break;
    end
    %@@@@@@@@@@@@@@@@@@
    Y=(abs(aa(i,2)-aa(i+1,2)));     % y in front
    X=(abs(aa(j,2)-aa(j+1,2)));     % x in back
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if(X>=Y && Y>0)
        %%%%%###############
        if(i==1) 
           B(kv,2)=0.5;
           am=[aa(i,2) aa(i+1,2)];
           B(kv,3)=am(1);
           B(kv,4)=am(2);         
           aa(1,:)=[];     % the circulation empties the first row each time, so every time only need to calculate the first row
        else 
           B(kv,2)=1;     % second colum of B is count of cycle; 
           am=[aa(i,2) aa(i+1,2)];
           B(kv,3)=am(1);    % third colum of B is the value of lower side of the range; 
           B(kv,4)=am(2);    % fourth colum of B is the value of upper side of the range; 
           aa(i+1,:)=[]; 
           aa(i,:)=[];
        end
        %%%%%###############
        B(kv,1)=Y;   % first colum of B is the range;  
        %######################
        if(Y>aamax) 
            p1=aa(i,2);
            tp1=aa(i,1);
            aamax=Y;
        end
        %######################
        kv=kv+1; 
        i=1;
        j=2;        
    else
        i=i+1;     % skip the rows that do not satisfy (X>=Y && Y>0)
        j=j+1;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
% #### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% #### %%
%  Count each range that has not been previously counted as one-half cycle.

N=max(size(aa));
%%#### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:N-1 
    Y=(abs(aa(i,2)-aa(i+1,2)));
    %$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    if(Y>0)
        B(kv,1)=Y; 
        B(kv,2)=0.5;
        am=[aa(i,2) aa(i+1,2)];
        B(kv,3)=am(1);
        B(kv,4)=am(2);   
        %&&&&&&&&&&&&&&&&&&&&&
        if(Y>aamax)
            p1=aa(i,2);
            tp1=aa(i,1);
            aamax=Y;
        end
        %&&&&&&&&&&&&&&&&&&&&&
        kv=kv+1;
    end
    %$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
end
%%#### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% #### %%
amax=max(B(:,1));       % find the maximum range
L(1)=0;
L(2)=2.5;
L(3)=5;
L(4)=10;
L(5)=15;
L(6)=20;
L(7)=30;
L(8)=40;
L(9)=50;
L(10)=60;
L(11)=70;
L(12)=80;
L(13)=90;
L(14)=100;
L=L*amax/100;      % L equals the percentage of the maximum range
%

num=max(size(L))-1;
C=zeros(num,1);
%
AverageMean=zeros(num,1);
MaxMean=-1.0e+09*ones(num,1);
MinMean= 1.0e+09*ones(num,1);
%
MaxPeak=-1.0e+09*ones(num,1);
MinValley= 1.0e+09*ones(num,1);
%
MaxAmp=zeros(num,1);
AverageAmp=zeros(num,1);
%
kvn=kv-1;
%
range_cycles=[B(1:kvn,1) B(1:kvn,2)];
amp_cycles=[0.5*B(1:kvn,1) B(1:kvn,2)];
%
for i=1:kvn          %kvn is the number of range points
     for ijk=1:num       %ijk is the number of the bins
        Y=B(i,1);
        if(Y>=L(ijk) && Y<=L(ijk+1))
            C(ijk)=C(ijk)+B(i,2);
            bm=(B(i,3)+B(i,4))/2;
            if(B(i,3)>MaxPeak(ijk))
                MaxPeak(ijk)=B(i,3);
            end
            if(B(i,4)>MaxPeak(ijk))
                MaxPeak(ijk)=B(i,4);
            end 
            if(B(i,3)<MinValley(ijk))
                MinValley(ijk)=B(i,3);
            end
            if(B(i,4)<MinValley(ijk))
                MinValley(ijk)=B(i,4);
            end              
%            
            AverageAmp(ijk)=AverageAmp(ijk)+B(i,1)*B(i,2);
            AverageMean(ijk)=AverageMean(ijk)+bm*B(i,2);
%
            if( bm > MaxMean(ijk))
                MaxMean(ijk)=bm;
            end
            if( bm < MinMean(ijk))
                MinMean(ijk)=bm;
            end       
%
            if(B(i,1)>MaxAmp(ijk))
               MaxAmp(ijk)=B(i,1);
            end
            break;
        end
    end   
end
for ijk=1:num
    if( C(ijk)>0)
       AverageAmp(ijk)=AverageAmp(ijk)/C(ijk);
       AverageMean(ijk)=AverageMean(ijk)/C(ijk);
    end
end

%
  N=max(size(C));
  BIG=zeros(N,10);

  MaxAmp=MaxAmp/2;
  AverageAmp=AverageAmp/2;
%
  for i=1:N
      j=N+1-i;
%
      if(C(j)==0)
         AverageAmp(j)=0.;
         MaxAmp(j)=0.;
         MinMean(j)=0.;
         AverageMean(j)=0.;
         MaxMean(j)=0.;
         MinValley(j)=0.;
         MaxPeak(j)=0.; 
      end

      BIG(i,1)=L(j);
      BIG(i,2)=L(j+1);
      BIG(i,3)=C(j);
      BIG(i,4)=AverageAmp(j);
      BIG(i,5)=MaxAmp(j);
      BIG(i,6)=MinMean(j);      
      BIG(i,7)=AverageMean(j);
      BIG(i,8)=MaxMean(j);   
      BIG(i,9)=MinValley(j); 
      BIG(i,10)=MaxPeak(j);   
  end  

end
