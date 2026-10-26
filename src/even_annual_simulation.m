%% EVEN annual community resilience simulation
%
% This file is a script so that it can be executed directly for a default
% run, and also called from EVEN_RUN_SCENARIO, which assigns the scenario
% parameters in its own workspace before invoking it. Every configurable
% parameter below is only assigned if the caller has not already set it,
% so a direct run reproduces the original default scenario exactly.
%
% Input data files may be overridden by setting GUI_MGFile, GUI_HHLoadFile
% and GUI_HHPVFile before calling.
% Load Inputs (Data in 2022)
%-------MG-related input parameters---------%
if ~exist('GUI_MGFile','var'),     GUI_MGFile     = 'MG_supply_demand.mat'; end
if ~exist('GUI_HHLoadFile','var'), GUI_HHLoadFile = 'HH_Load.mat';          end
if ~exist('GUI_HHPVFile','var'),   GUI_HHPVFile   = 'HH_PV_supply2.mat';    end
if ~exist('GUI_MGSupplyCase','var'), GUI_MGSupplyCase = 1;                  end
if ~exist('GUI_DemandScale','var'),  GUI_DemandScale  = 1;                  end

MG_supply_demand = load(GUI_MGFile); %MG supply & demand data: variables: MG_Load, MG_Supply1(base case),MG_Supply2 (case2),MG_Supply3 (case3)
MG_demand = sum(MG_supply_demand.MG_Load,2); % MG_Load has 8 individual load profiles
switch GUI_MGSupplyCase
    case 2, MG_supply = sum(MG_supply_demand.MG_Supply2,2);
    case 3, MG_supply = sum(MG_supply_demand.MG_Supply3,2);
    otherwise, MG_supply = sum(MG_supply_demand.MG_Supply1,2);
end

MG_daily_demand = (sum(reshape(MG_demand,24,365)))'; % MG_Load has 8 individual load profiles
MG_daily_supply = (sum(reshape(MG_supply,24,365)))'; % MG_Load has 8 individual load profiles

%-------Households-related input parameters---------%
load(GUI_HHLoadFile);
load(GUI_HHPVFile);
HH_demand_col = household_demand * GUI_DemandScale;
HH_supply_col= PV_supply;

[~,N_HH_total]=size(HH_supply_col);
for n_HH=1:N_HH_total
    HH_daily_demand(:,n_HH)=(sum(reshape(HH_demand_col(:,n_HH),24,365)))';
    HH_daily_supply(:,n_HH)=(sum(reshape(HH_supply_col(:,n_HH),24,365)))';
end

%% Configure simulation scenarios
% EV_number = percent*Total_Smed_Houses 5357; [0.05, 0.1, 0.2, 0.4, 0.8]
if ~exist('EV_PenetrationLevel','var'), EV_PenetrationLevel = 0.05; end
% PV_number = percent*EV_number; [0.25, 0.5, 0.8, 1]
if ~exist('PV_penetration','var'),      PV_penetration      = 0.25; end
% Battery_number = percent*PV_number; [0.11, 0.3]
if ~exist('Battery_penetration','var'), Battery_penetration = 0.11; end
% 1 when non-emergency inverter is used, 2 when emergency inverters are used
if ~exist('scenario_inverter','var'),   scenario_inverter   = 1;    end
% Auction and balancing market, input to f_AuctionAndBalancingMarket_V2MG
if ~exist('scenario_auction','var'),    scenario_auction    = 2;    end

% derive number of houses for each simulation % Extract scenario ratios for PV_B, OnlyPV, and NoPV
num_houses =round(size(HH_demand_col, 2)*EV_PenetrationLevel);
Num_PV_B = round(Battery_penetration*PV_penetration*num_houses);
Num_PVOnly = round(PV_penetration*num_houses)-Num_PV_B;
Num_NoPV= num_houses-(Num_PV_B+Num_PVOnly);
Num_NO_PV_prod=round(Num_NoPV+Num_PVOnly); %Considering PV only houses as no production of PV

%% Define battery information
% Constants below are defined centrally in even_parameters.m. A caller may
% supply its own P_even (for example even_run_parametric, which reproduces
% the settings of the published parametric studies).
if ~exist('P_even','var'), P_even = even_parameters(); end
%----------MG battery-------------%
% MG_eff_B_charge = 0.95; MG_eff_B_dischg = 0.95;% this part of parameters are fixed
MG_eff_B_charge = P_even.community.MG_battery_efficiency;
MG_eff_B_dischg = P_even.community.MG_battery_efficiency;
MG_SoCBmin = P_even.community.MG_SOC_min;
MG_SoCB0 = P_even.community.MG_SOC_initial;
% MG battery capacity in kWh; 1000 to 5000 considered in the study
if ~exist('MG_B','var'), MG_B = 2000; end
MG_Bclimit = P_even.community.MG_charge_limit_fraction*MG_B;
MG_Bdlimit = P_even.community.MG_discharge_limit_kW; % in unit of kW

%-------Households battery---------%
% HH_eff_B_charge = 0.95; HH_eff_B_dischg = 0.95; % this part of parameters are fixed
HH_eff_B_charge = P_even.community.HH_battery_efficiency;
HH_eff_B_dischg = P_even.community.HH_battery_efficiency;
HH_SoCBmin = P_even.community.HH_SOC_min;
HH_SoCB0 = P_even.community.HH_SOC_initial;
HH_B = P_even.community.HH_battery_kWh;
HH_Bclimit = P_even.community.HH_charge_limit_kW;
HH_Bdlimit = P_even.community.HH_discharge_limit_kW;

%-------EV battery---------%
eff_EVB_round = P_even.community.EV_battery_efficiency;
SoCEVBmin = P_even.community.EV_SOC_min;
% BYD Dolphin 44.9 kWh Boost (44.9 kWh usable, 56 including SoCEVBmin).
% Tesla Model Y Performance would be EVB = 93.75.
if ~exist('EVB','var'), EVB = 56; end
EVBclimit = P_even.community.EV_power_limit_kW;
% 2.48 kWh daily energy consumption of EVs in Europe, 12 km/day (EVbox)
EV_travel = P_even.community.EV_travel_kWh_per_day;
% 203 W/km over 3 km each way between a household and the microgrid
EV_travel_MG = P_even.community.EV_travel_to_MG_kWh;

%% Evaluate the daily energy balance and delivery potential (only in Category 1 and Category (scenario2))
%---------MG energy balance-------------%
[MG_Esurplus, MG_SoCB, MG_red_demand, MG_cut_prod, MG_B_e_cha_disch_int, MG_B_e_cha_disch_ext] = f_MG_OnlyBattery(MG_supply, MG_demand, MG_B, MG_SoCBmin, MG_SoCB0, MG_Bclimit, MG_Bdlimit, MG_eff_B_charge, MG_eff_B_dischg);
% MG_OUTPUT_MATRIX=[MG_supply, MG_demand,MG_Esurplus, MG_red_demand, MG_cut_prod, MG_B_e_cha_disch_int, MG_B_e_cha_disch_ext];
MG_Balance_daily=(sum(reshape(MG_supply-MG_demand-MG_B_e_cha_disch_ext,24,365)))'; % evalutate MG balance after battery regulation.

%--------Household balance--------------%
    % ---------------Category_1 PV+Battery--------%
    cat1_EnergyBalance_daily=zeros(365,Num_PV_B); cat1_EnergyDeliveryPotential_daily=zeros(365, Num_PV_B);
    
    for j = 1:Num_PV_B
          demand_j = HH_demand_col(:, j);  % Extract demand for the current column
          supply_j=HH_supply_col(:, j); 
        
         [Esurplus, SoCB, red_demand, cut_prod, B_e_charge_discharge] = f_BatteryOnly(supply_j, demand_j, HH_B, HH_SoCBmin, HH_SoCB0, HH_Bclimit, HH_Bdlimit, HH_eff_B_charge, HH_eff_B_dischg);
       
         cat1_cut_prod_daily = (sum(reshape(cut_prod, 24, []), 1))'; 
         cat1_red_demand_daily = (sum(reshape(red_demand, 24, []), 1))'; 
         cat1_EnergyBalance_daily(:,j)=round(cat1_cut_prod_daily-cat1_red_demand_daily);
    
         cat1_EnergyDeliveryPotential_daily_Suplus_max = max(0,eff_EVB_round * (cat1_EnergyBalance_daily(:,j) - EV_travel - EV_travel_MG)); % Calculate the maximum surplus energy delivery potential for each consumer
         cat1_EnergyDeliveryPotential_daily_EVBattery_max= eff_EVB_round* (EVB*(1-SoCEVBmin)- EV_travel-EV_travel_MG);
         cat1_EnergyDeliveryPotential_daily(:,j)=min(cat1_EnergyDeliveryPotential_daily_Suplus_max,cat1_EnergyDeliveryPotential_daily_EVBattery_max);
    end

    % ---------------Category_2 PV only-----------%
    cat2_EnergyBalance_daily=zeros(365,Num_PVOnly); cat2_EnergyDeliveryPotential_daily=zeros(365, Num_PVOnly);
    
    switch scenario_inverter
        case 1
            for k = 1:Num_PVOnly
                 demand_k = HH_demand_col(:, k+Num_PV_B);  % Extract demand for the current column
                 supply_k=zeros(8760,1); 
                   
                 cat2_EnergyBalance_daily(:,k)=(round(sum(reshape(supply_k-demand_k,24,365),1)))';
            
                 cat2_EnergyDeliveryPotential_daily_Suplus_max = max(0,eff_EVB_round * (cat2_EnergyBalance_daily(:,k) - EV_travel - EV_travel_MG)); % Calculate the maximum surplus energy delivery potential for each consumer
                 cat2_EnergyDeliveryPotential_daily_EVBattery_max= eff_EVB_round* (EVB*(1-SoCEVBmin)- EV_travel-EV_travel_MG);
                 cat2_EnergyDeliveryPotential_daily(:,j)=min(cat2_EnergyDeliveryPotential_daily_Suplus_max,cat2_EnergyDeliveryPotential_daily_EVBattery_max);
            end
        case 2
            for k = 1:Num_PVOnly
                 demand_k = HH_demand_col(:, k+Num_PV_B);  % Extract demand for the current column
                 supply_k=HH_supply_col(:, k+Num_PV_B); 
    
                 cat2_EnergyBalance_daily(:,k)=(round(sum(reshape(supply_k-demand_k,24,365),1)))';
            
                 cat2_EnergyDeliveryPotential_daily_Suplus_max = max(0,eff_EVB_round * (cat2_EnergyBalance_daily(:,k) - EV_travel - EV_travel_MG)); % Calculate the maximum surplus energy delivery potential for each consumer
                 cat2_EnergyDeliveryPotential_daily_EVBattery_max= eff_EVB_round* (EVB*(1-SoCEVBmin)- EV_travel-EV_travel_MG);
                 cat2_EnergyDeliveryPotential_daily(:,k)=min(cat2_EnergyDeliveryPotential_daily_Suplus_max,cat2_EnergyDeliveryPotential_daily_EVBattery_max);
            end
    end

    % ---------------Category_3 no PV  (no surplus energy to share)--------%
    cat3_EnergyBalance_daily=zeros(365,Num_NoPV);
    
    for m = 1:Num_NoPV
    
        demand_m = HH_demand_col(:, m+Num_PVOnly+Num_PV_B); % Adjusted index to match the desired column & Extract demand for the current column
        supply_m=zeros(8760,1); 

        cat3_EnergyBalance_daily(:,m)=round((sum(reshape(supply_m-demand_m,24,365),1))');

    end

% Generate the final daily energy balance tables
All_household_EnergyBalance_daily=round([cat1_EnergyBalance_daily, cat2_EnergyBalance_daily, cat3_EnergyBalance_daily]);

%% Auction and balancing market: Simulate the households daily energy balance
% MG2V = 10; % assumed 10 kWh for each first arriving EVs

Output_daily_Action=[]; Output_daily_EBalance_before=[]; Output_daily_EBalance_after=[];
Output_daily_transition=zeros(365,3); % Column1:MG2C,Column2:P2MG,Column3:P2MG2C (negative value all the time 
Output_daily_MG_Prosumer_Comsumer=zeros(365,3); % Column1:MG Action,Column2:Prosumer Action,Column3:Consumer Action (negative-sell, positive-buy 

for t = 1:365 %evaluate the action in each day
    MG_Balance_daily_i = MG_Balance_daily(t,:);
    All_household_EnergyBalance_daily_i = All_household_EnergyBalance_daily(t,:);

    [Action_buy_or_sell, EnergyBalance_before, EnergyBalance_after] = f_AuctionAndBalancingMarket_V2MG(MG_Balance_daily_i, All_household_EnergyBalance_daily_i', scenario_auction, EV_travel, EV_travel_MG, eff_EVB_round, EVB, SoCEVBmin);
    
    EnergyBalance_after(find(EnergyBalance_after<0.1 & EnergyBalance_after>-0.1))=0; % if the deviation is too small, then force it to be balanced.

    % Store the output matrices
    Output_daily_Action(t,:) = Action_buy_or_sell;  % negative means sell, and positive means buy
    Output_daily_EBalance_before(t,:) = EnergyBalance_before;  % positive means surplus, negative means deficit
    Output_daily_EBalance_after(t,:) = EnergyBalance_after;

    Act_MG_Prosumer_Consumer=[Action_buy_or_sell(1),sum(Action_buy_or_sell(2:end).*(Action_buy_or_sell(2:end) < 0)),sum(Action_buy_or_sell(2:end).*(Action_buy_or_sell(2:end) > 0))]; %MG,P,C
    Output_daily_MG_Prosumer_Comsumer(t,:)=Act_MG_Prosumer_Consumer;

    if sum(Act_MG_Prosumer_Consumer)==0
        Output_daily_transition(t,:)=zeros(1,3); 
    else
        if Act_MG_Prosumer_Consumer(2)<0 && Act_MG_Prosumer_Consumer(1)<0
            Output_daily_transition(t,1)=Act_MG_Prosumer_Consumer(1);   % MG2C
            Output_daily_transition(t,2)=0;                             % P2MG
            Output_daily_transition(t,3)=Act_MG_Prosumer_Consumer(2);   % P2MG2C
        elseif Act_MG_Prosumer_Consumer(2)<0 && Act_MG_Prosumer_Consumer(1)>0 && Act_MG_Prosumer_Consumer(3)==0
            Output_daily_transition(t,1)=0;                             % MG2C
            Output_daily_transition(t,2)=Act_MG_Prosumer_Consumer(2);   % P2MG
            Output_daily_transition(t,3)=0;                             % P2MG2C
        elseif Act_MG_Prosumer_Consumer(2)<0 && Act_MG_Prosumer_Consumer(1)>0 && Act_MG_Prosumer_Consumer(3)>0
            Output_daily_transition(t,1)=0;                             % MG2C
            Output_daily_transition(t,2)=Act_MG_Prosumer_Consumer(2)*Act_MG_Prosumer_Consumer(1)/(Act_MG_Prosumer_Consumer(1)+Act_MG_Prosumer_Consumer(3));   % P2MG
            Output_daily_transition(t,3)=Act_MG_Prosumer_Consumer(2)*Act_MG_Prosumer_Consumer(3)/(Act_MG_Prosumer_Consumer(1)+Act_MG_Prosumer_Consumer(3));   % P2MG2C
        elseif Act_MG_Prosumer_Consumer(2)==0 && Act_MG_Prosumer_Consumer(1)<0
            Output_daily_transition(t,1)=Act_MG_Prosumer_Consumer(1);   % MG2C
            Output_daily_transition(t,2)=0;                             % P2MG
            Output_daily_transition(t,3)=0;   % P2MG2C    
        end
    end

end
 
%% Further analysis based on the output matrix
%----Daily energy loss-(AGGREGATED+Percent+BreakdownEachWay)--------------%
Output_daily_Action_middle_sell=Output_daily_Action; Output_daily_Action_middle_sell(Output_daily_Action>0)=0;
Output_daily_index_Eloss(:,1) = abs(sum(Output_daily_Action, 2)); % Amount in kWh, total daily energy loss of energy transaction
Output_daily_index_Eloss(:,2) = abs(sum(Output_daily_Action, 2))./max(abs(sum(Output_daily_Action_middle_sell, 2)),0.1); % percentage in %, daily energy loss of energy transaction
Output_daily_index_Eloss(:,3:5) = abs(repmat(Output_daily_index_Eloss(:,2),1,3).*Output_daily_transition); % Amount in kWh, daily energy loss for each way of delivery
%----Number of days with power deficits for each individual MG+HH---------%
Output_sum_index_Ndays_deficits=[sum(Output_daily_EBalance_before<0);sum(Output_daily_EBalance_after<0)];
%----Total amount of power deficits for each individual MG+HH-------------%
Output_daily_Deficit_before_middle=Output_daily_EBalance_before; Output_daily_Deficit_before_middle(Output_daily_EBalance_before>0)=0;
Output_daily_Deficit_after_middle=Output_daily_EBalance_after; Output_daily_Deficit_after_middle(Output_daily_EBalance_after>0)=0;
Output_sum_Indiv_index_Edeficits=[sum(Output_daily_Deficit_before_middle);sum(Output_daily_Deficit_after_middle)];
%----Total amount of power surplus for each individual MG+HH-------------%
Output_daily_Surplus_before_middle=Output_daily_EBalance_before; Output_daily_Surplus_before_middle(Output_daily_EBalance_before<0)=0;
Output_daily_Surplus_after_middle=Output_daily_EBalance_after; Output_daily_Surplus_after_middle(Output_daily_EBalance_after<0)=0;
Output_sum_Indiv_index_Esurplus=[sum(Output_daily_Surplus_before_middle);sum(Output_daily_Surplus_after_middle)];
%----SS and SC imrpoved by EVs for each individual MG+HH-----------------%
Output_daily_EV_SC=abs(Output_daily_Action)./round([MG_daily_demand,HH_daily_demand(:,1:num_houses)]); % daily ev delivery (both buy and sell) compared to the daily demand
Output_daily_EV_SS=abs(Output_daily_Action)./round([MG_daily_supply,HH_daily_supply(:,1:num_houses)]);
Output_sum_Indiv_EV_SC_SS(1,:)=sum(abs(Output_daily_Action))./sum([MG_daily_demand,HH_daily_demand(:,1:num_houses)]); % total ev delivery (both buy and sell) compared to the daily demand
% Output_sum_Indiv_EV_SC_SS(2,:)=sum(abs(Output_daily_Action))./sum([MG_daily_supply,HH_daily_supply(:,1:num_houses)]);

%% Further analysis the EV battery degradation due to the electricity delivery
for n2_HH=1:num_houses
    EV_Cha_Discha_orig1=[]; EV_Cha_Discha_orig2=[];EV_Cha_Discha=[]; DoD_i=[];RangeCycle_i=[];

    EV_Cha_Discha_orig1=EVB-abs(nonzeros(Output_daily_Action(:,1+n2_HH))); EV_Cha_Discha_orig2=[EVB*ones(length(EV_Cha_Discha_orig1),1),EV_Cha_Discha_orig1]';
    EV_Cha_Discha=reshape(EV_Cha_Discha_orig2,2*length(EV_Cha_Discha_orig1),1);
    DoD_i=1-EV_Cha_Discha/EVB;
    RangeCycle_i=func_rainflow(DoD_i); subdegrade=func_dod_cycle(RangeCycle_i); 
    Degradation(n2_HH)=sum(subdegrade);
end

Output_sum_Indiv_all=abs([Output_sum_index_Ndays_deficits;Output_sum_Indiv_index_Edeficits;Output_sum_Indiv_index_Esurplus;Output_sum_Indiv_EV_SC_SS;[0,Degradation]]);

%% This part is the aggregated level performance, which will be used in scenario analysis

% Output_sum_Agg_index_All(1,ijk1)=Output_sum_Indiv_index_Edeficits(1,1);  % MG-total deficits before;
% Output_sum_Agg_index_All(2,ijk1)=Output_sum_Indiv_index_Edeficits(2,1);  % MG-total deficits after;
% Output_sum_Agg_index_All(3,ijk1)=(Output_sum_Indiv_index_Edeficits(1,1)-Output_sum_Indiv_index_Edeficits(2,1))/Output_sum_Indiv_index_Edeficits(1,1);    % perf improvement
% Output_sum_Agg_index_All(4,ijk1)=Output_sum_index_Ndays_deficits(1,1);   % MG-total number of days with deficits before;
% Output_sum_Agg_index_All(5,ijk1)=Output_sum_index_Ndays_deficits(2,1);   % MG-total number of days with deficits before;
% Output_sum_Agg_index_All(6,ijk1)=(Output_sum_index_Ndays_deficits(1,1)-Output_sum_index_Ndays_deficits(2,1))/Output_sum_index_Ndays_deficits(1,1);       % perf improvement
% Output_sum_Agg_index_All(7,ijk1)=sum(Output_sum_Indiv_index_Edeficits(1,2:end))/num_houses;  % HH-total deficits before;
% Output_sum_Agg_index_All(8,ijk1)=sum(Output_sum_Indiv_index_Edeficits(2,2:end))/num_houses;  % HH-total deficits after;
% Output_sum_Agg_index_All(9,ijk1)=(sum(Output_sum_Indiv_index_Edeficits(1,2:end))-sum(Output_sum_Indiv_index_Edeficits(2,2:end)))/sum(Output_sum_Indiv_index_Edeficits(1,2:end));       % perf improvement
% Output_sum_Agg_index_All(10,ijk1)=sum(Output_sum_index_Ndays_deficits(1,2:end))/num_houses;  % HH-total number of days with deficits before;
% Output_sum_Agg_index_All(11,ijk1)=sum(Output_sum_index_Ndays_deficits(2,2:end))/num_houses;  % HH-total number of days with deficits after;
% Output_sum_Agg_index_All(12,ijk1)=(sum(Output_sum_index_Ndays_deficits(1,2:end))-sum(Output_sum_index_Ndays_deficits(2,2:end)))/sum(Output_sum_index_Ndays_deficits(1,2:end));         % perf improvement
% Output_sum_Agg_index_All(13,ijk1)=Output_sum_Indiv_EV_SC_SS(1,1); % MG-total SC
% Output_sum_Agg_index_All(14,ijk1)=0;%Output_sum_Indiv_EV_SC_SS(2,1); % MG-total SS
% Output_sum_Agg_index_All(15,ijk1)=mean(Output_sum_Indiv_EV_SC_SS(1,2:end)); % HH-total SC
% Output_sum_Agg_index_All(16,ijk1)=0;%mean(Output_sum_Indiv_EV_SC_SS(2,2:end)); % HH-total SS
% Output_sum_Agg_index_All(17,ijk1)=abs(round(sum(Output_daily_transition(:,1)))); % Power delivery MG2C
% Output_sum_Agg_index_All(18,ijk1)=abs(round(sum(Output_daily_transition(:,2)))); % Power delivery P2MG
% Output_sum_Agg_index_All(19,ijk1)=abs(round(sum(Output_daily_transition(:,3)))); % Power delivery P2MG2C
% Output_sum_Agg_index_All(20,ijk1)=sum(Output_daily_index_Eloss(:,1)); % Total energy loss
% Output_sum_Agg_index_All(21,ijk1)=sum(Output_daily_index_Eloss(:,1))/sum(abs(sum(Output_daily_Action_middle_sell, 2))); % Total energy loss ratio

%%
Output_daily_Action_delivery=Output_daily_Action(:,2:end); N_Action_delivery=nnz(Output_daily_Action_delivery); N_Action_travel=nnz(Output_daily_EBalance_before(:,2:end)>EV_travel);
E_EV_SUM_travel_MG=N_Action_delivery*EV_travel_MG;
E_EV_SUM_travel=N_Action_travel*EV_travel;
E_EV_SUM=E_EV_SUM_travel_MG+E_EV_SUM_travel;
%%

Output_all_demand=[MG_daily_demand,HH_daily_demand(:,1:num_houses)];
Output_all_supply=Output_daily_EBalance_after+Output_all_demand;
Output_all_demand_met=min(Output_all_demand,Output_all_supply);

ijk1=1; ijk2=1;
OUTPUT_paramatric_PartA(1,ijk1,ijk2)=nnz(Output_daily_EBalance_before<0)/numel(Output_daily_EBalance_before);     % Ratio of days with deficits
OUTPUT_paramatric_PartA(2,ijk1,ijk2)=nnz(Output_daily_EBalance_after<0)/numel(Output_daily_EBalance_after);     % Ratio of days with deficits
OUTPUT_paramatric_PartA(3,ijk1,ijk2)=(sum(sum(Output_all_demand_met))+E_EV_SUM)/(sum(MG_daily_demand)+sum(sum(HH_daily_demand(:,1:num_houses)))+E_EV_SUM);     % Ratio of SC
OUTPUT_paramatric_PartA(4,ijk1,ijk2)=(sum(sum(Output_all_demand_met))+E_EV_SUM)/(sum(MG_daily_supply)+sum(sum(HH_daily_supply(:,1:(Num_PV_B+Num_PVOnly)))));   % Ratio of SS
OUTPUT_paramatric_PartA(5,ijk1,ijk2)=mean(Degradation);     % mean degradation rates

OUTPUT_paramatric_PartB(1,ijk1,ijk2)=min(Degradation);
OUTPUT_paramatric_PartB(2:4,ijk1,ijk2)=quantile(Degradation,[.25 .5 .75])';
OUTPUT_paramatric_PartB(5,ijk1,ijk2)=max(Degradation);


%%

Output_all_demand=[MG_daily_demand,HH_daily_demand(:,1:num_houses)];
Output_all_supply2=Output_daily_EBalance_before+Output_all_demand;
Output_all_demand_met2=min(Output_all_demand,Output_all_supply2);

SC=(sum(sum(Output_all_demand_met2))+E_EV_SUM_travel)/(sum(MG_daily_demand)+sum(sum(HH_daily_demand(:,1:num_houses)))+E_EV_SUM_travel);     % Ratio of SC
SS=(sum(sum(Output_all_demand_met2))+E_EV_SUM_travel)/(sum(MG_daily_supply)+sum(sum(HH_daily_supply(:,1:(Num_PV_B+Num_PVOnly)))));   % Ratio of SS
