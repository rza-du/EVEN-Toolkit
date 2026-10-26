function [Action_buy_or_sell,EnergyBalance_before,EnergyBalance_after] = f_AuctionAndBalancingMarket_V2MG(MG_Balance_daily_i,All_household_EnergyBalance_daily_i,scenario,EV_travel,EV_travel_MG,eff_EVB_round,EVB,SoCEVBmin)
%F_AUCTIONANDBALANCINGMARKET this function make evaluation under three
%different balancing approaches
% Scenario=1: each demanding/selling households makes a fixed amount of contribution 5kWh or 10 kWh (first come, first reserved)
% Scenario=2: each demanding/selling households makes a flexible amount of % contribution as much as they want (first come, first reserved)
% Scenario=3: demanding/selling households makes a contribution based on the ratio 
% MG_Balance_daily_i and daily balance, if it is positive, it means it is
% surplus, and if it is negative, it is deficit. 

% %-------Test inputs--------%
% f_AuctionAndBalancingMarket_V2MG(MG_Balance_daily_i,All_household_EnergyBalance_daily_i,scenario,EV_travel,EV_travel_MG,eff_EVB_round,EVB,SoCEVBmin);
% f_AuctionAndBalancingMarket_V2MG(MG_Balance_daily_i,All_household_EnergyBalance_daily_i,scenario,EV_travel,EV_travel_MG,eff_EVB_round,EVB,SoCEVBmin)

% day=110;
% All_household_EnergyBalance_daily_i=All_household_EnergyBalance_daily(:,day);
% MG_Balance_daily_i=100;%MG_Balance_daily(day);
% scenario=2;
% E_travel=0;%2.48;
% E_MG=1.218;
% eff_EVB_round=0.9;
% EVB=50;
% SoCEVBmin=0.2;
%-----
Threshold_Delivery=0; % when the available delivered E is larger than this threshold, delivery is considered. 

Action_buy_or_sell=zeros(1+length(All_household_EnergyBalance_daily_i),1); 
EnergyBalance_before=[MG_Balance_daily_i;All_household_EnergyBalance_daily_i]; EnergyBalance_after=EnergyBalance_before;

ID_H_surplus=find(All_household_EnergyBalance_daily_i>0); Number_H_surplus=length(ID_H_surplus);
ID_H_deficit=find(All_household_EnergyBalance_daily_i<0); Number_H_deficit=length(ID_H_deficit);

E_H_surplus=All_household_EnergyBalance_daily_i(ID_H_surplus); E_H_surplus_deliver=min(eff_EVB_round*(E_H_surplus-EV_travel-EV_travel_MG),eff_EVB_round*(EVB*(1-SoCEVBmin)- EV_travel-EV_travel_MG)); E_H_surplus_deliver(E_H_surplus_deliver<Threshold_Delivery)=0;
E_H_deficit=All_household_EnergyBalance_daily_i(ID_H_deficit); E_H_deficit_deliver=(max(E_H_deficit,-EVB*(1-SoCEVBmin))-EV_travel_MG)/eff_EVB_round;  % if there is large deficits, the EV is considered not used for commuting to work (other transport).

%disp(E_H_deficit_deliver)

%%
switch true
    %%
    case scenario==1 % each households buys a fixed amount of energy for instance MG2V= 5kWh or 10 kWh (first come, first reserved)

%% It is ready to be used.
    case scenario==2 % each demanding/selling households makes a flexible amount of % contribution as much as they want (first come, first reserved)
        if MG_Balance_daily_i>0 % MG has surplus 
            if MG_Balance_daily_i>abs(sum(E_H_deficit_deliver)) % MG has surplus production enough to meet large demand.
                Action_buy_or_sell(1)=sum(E_H_deficit_deliver);             % sell (negative) The total sell and buy should be zeros
                Action_buy_or_sell(1+ID_H_surplus)=0;
                Action_buy_or_sell(1+ID_H_deficit)=-(E_H_deficit_deliver*eff_EVB_round+EV_travel_MG);    % buy (positive)
                % disp(Action_buy_or_sell(1+ID_H_deficit))
            else % MG does not have surplus production enough to meet large demand.
                if abs(sum(E_H_deficit_deliver))-MG_Balance_daily_i>sum(E_H_surplus_deliver) % both MG and house_surplus cannot meet the large demand.
                    Action_buy_or_sell(1)=-MG_Balance_daily_i;                   % sell 
                    Action_buy_or_sell(1+ID_H_surplus)=-(E_H_surplus_deliver/eff_EVB_round+EV_travel+EV_travel_MG);             % sell 
                    %---------------33333333333333----------------
                    i=1; E_H_deficit_deliver_until_i=0;
                    while abs(E_H_deficit_deliver(i))<MG_Balance_daily_i+sum(E_H_surplus_deliver)-abs(E_H_deficit_deliver_until_i)
                        E_H_deficit_deliver_until_i=sum(E_H_deficit_deliver(1:i));
                        Action_buy_or_sell(1+ID_H_deficit(i))=-(E_H_deficit_deliver(i)*eff_EVB_round+EV_travel_MG); % buy (positive)
                        i=i+1;
                    end
                    Action_buy_or_sell(1+ID_H_deficit(i))=((MG_Balance_daily_i+sum(E_H_surplus_deliver)-abs(E_H_deficit_deliver_until_i)))*eff_EVB_round-EV_travel_MG; % buy (positive)
                    Action_buy_or_sell(1+ID_H_deficit(i+1:end))=0;
                    %------------------------3----------------------
                else  
                    Action_buy_or_sell(1)=-MG_Balance_daily_i;                  % sell 
                    %---------------22222222222222-----------------
                    i=1; E_H_surplus_deliver_until_i=0;
                    while E_H_surplus_deliver(i)<=abs(MG_Balance_daily_i+sum(E_H_deficit_deliver))-E_H_surplus_deliver_until_i
                        E_H_surplus_deliver_until_i=sum(E_H_surplus_deliver(1:i));
                        Action_buy_or_sell(1+ID_H_surplus(i))=-(E_H_surplus_deliver(i))/eff_EVB_round-EV_travel-EV_travel_MG; %-E_H_surplus(i); % sell (negative)
                        i=i+1;
                    end
                    Action_buy_or_sell(1+ID_H_surplus(i))=(MG_Balance_daily_i+E_H_surplus_deliver_until_i-abs(sum(E_H_deficit_deliver)))/eff_EVB_round-EV_travel-EV_travel_MG; % sell (negative)
                    Action_buy_or_sell(1+ID_H_surplus(i+1:end))=0;
                    %----------------------2-------------------------                    
                    Action_buy_or_sell(1+ID_H_deficit)=-E_H_deficit;    % buy (positive)
                end
            end
             EnergyBalance_after=EnergyBalance_before+Action_buy_or_sell; 
        else  % MG has deficits (it is negative)
            if abs(MG_Balance_daily_i)>sum(E_H_surplus_deliver) % MG has large demand which cannot be met by the large production.
                Action_buy_or_sell(1)=sum(E_H_surplus_deliver);                  % buy (positive)
                Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-(E_H_surplus_deliver(E_H_surplus_deliver>Threshold_Delivery))/eff_EVB_round-EV_travel-EV_travel_MG;                 % sell (negative)
                Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver==0))=0;                 % if the amount of surplus is small, then do not deliver
                Action_buy_or_sell(1+ID_H_deficit)=0;  
            else % MG has large demand, but it can be met by the large productions
                if sum(E_H_surplus_deliver)-abs(MG_Balance_daily_i)>sum(abs(E_H_deficit_deliver)) % both MG and households demand can be met.
                    Action_buy_or_sell(1)=abs(MG_Balance_daily_i);                   % buy (positive)
                    %---------------22222222222222-----------------
                    i=1; E_H_surplus_deliver_until_i=0;
                    while E_H_surplus_deliver(i)<=abs(MG_Balance_daily_i+sum(E_H_deficit_deliver))-E_H_surplus_deliver_until_i
                        E_H_surplus_deliver_until_i=sum(E_H_surplus_deliver(1:i));
                        Action_buy_or_sell(1+ID_H_surplus(i))=-(E_H_surplus_deliver(i))/eff_EVB_round-EV_travel-EV_travel_MG; % sell (negative)
                        i=i+1;
                    end
                    Action_buy_or_sell(1+ID_H_surplus(i))=(MG_Balance_daily_i+E_H_surplus_deliver_until_i-abs(sum(E_H_deficit_deliver)))/eff_EVB_round-EV_travel-EV_travel_MG; % sell (negative)
                    Action_buy_or_sell(1+ID_H_surplus(i+1:end))=0;
                    %-----------------------2----------------------                      
                    Action_buy_or_sell(1+ID_H_deficit)=abs(E_H_deficit);            % Buy (positive)
                else % the MG demand can be met, just part of the large HD can be met
                    Action_buy_or_sell(1)=abs(MG_Balance_daily_i); 
                    Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-(E_H_surplus_deliver(E_H_surplus_deliver>Threshold_Delivery))/eff_EVB_round-EV_travel-EV_travel_MG;
                    %---------------33333333333333----------------
                    i=1; E_H_deficit_deliver_until_i=0;
                    while abs(E_H_deficit_deliver(i))<MG_Balance_daily_i+sum(E_H_surplus_deliver)-abs(E_H_deficit_deliver_until_i)
                        E_H_deficit_deliver_until_i=sum(E_H_deficit_deliver(1:i));
                        Action_buy_or_sell(1+ID_H_deficit(i))=-E_H_deficit(i); % buy (positive)
                        i=i+1;
                    end
                    Action_buy_or_sell(1+ID_H_deficit(i))=((MG_Balance_daily_i+sum(E_H_surplus_deliver)-abs(E_H_deficit_deliver_until_i)))*eff_EVB_round-EV_travel_MG; % buy (positive)
                    Action_buy_or_sell(1+ID_H_deficit(i+1:end))=0;
                    %--------------------3------------------------
                end 
            end
            
            EnergyBalance_after=EnergyBalance_before+Action_buy_or_sell;
        end


    %% % it is ready to be used.
    case scenario==3 % demanding/selling households makes an equal share of contribution

        % if MG_Balance_daily_i>0 % MG has surplus 
        %     if MG_Balance_daily_i>abs(sum(E_H_deficit_deliver)) % MG has surplus production enough to meet large demand.
        %         Action_buy_or_sell(1)=sum(E_H_deficit_deliver);             % sell (negative) The total sell and buy should be zeros
        %         Action_buy_or_sell(1+ID_H_surplus)=0;
        %         Action_buy_or_sell(1+ID_H_deficit)=-E_H_deficit;    % buy (positive)
        %     else % MG does not have surplus production enough to meet large demand.
        %         if abs(sum(E_H_deficit_deliver))-MG_Balance_daily_i>sum(E_H_surplus_deliver) % both MG and house_surplus cannot meet the large demand.
        %             Action_buy_or_sell(1)=-MG_Balance_daily_i;                   % sell 
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-(E_H_surplus_deliver(E_H_surplus_deliver>Threshold_Delivery))/eff_EVB_round-EV_travel-EV_travel_MG;             % sell 
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver==Threshold_Delivery))=0;             % sell 
        %             Action_buy_or_sell(1+ID_H_deficit)=(MG_Balance_daily_i+sum(E_H_surplus_deliver))*abs(E_H_deficit_deliver)/abs(sum(E_H_deficit_deliver)); %buy
        %         else
        %             Action_buy_or_sell(1)=-MG_Balance_daily_i;                  % sell 
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-E_H_surplus(E_H_surplus_deliver>Threshold_Delivery)/sum(E_H_surplus)*(abs(sum(E_H_deficit_deliver))-MG_Balance_daily_i);        % sell 
        %             Action_buy_or_sell(1+ID_H_deficit)=-E_H_deficit;    % buy (positive)
        %         end
        %     end
        %      EnergyBalance_after=EnergyBalance_before+Action_buy_or_sell; 
        % else  % MG has deficits (it is negative)
        %     if abs(MG_Balance_daily_i)>sum(E_H_surplus_deliver) % MG has large demand which cannot be met by the large production.
        %         Action_buy_or_sell(1)=sum(E_H_surplus_deliver);                  % buy (positive)
        %         Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-(E_H_surplus_deliver(E_H_surplus_deliver>Threshold_Delivery))/eff_EVB_round-EV_travel-EV_travel_MG;                 % sell (negative)
        %         Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver==Threshold_Delivery))=0;                 % if the amount of surplus is small, then do not deliver
        %         Action_buy_or_sell(1+ID_H_deficit)=0;  
        %     else % MG has large demand, but it can be met by the large productions
        %         if sum(E_H_surplus_deliver)-abs(MG_Balance_daily_i)>sum(abs(E_H_deficit_deliver)) % both MG and households demand can be met.
        %             Action_buy_or_sell(1)=abs(MG_Balance_daily_i);                   % buy (positive)
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-E_H_surplus(E_H_surplus_deliver>Threshold_Delivery)/sum(E_H_surplus)*(abs(MG_Balance_daily_i)+sum(abs(E_H_deficit_deliver))); % sell (negative)
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver==Threshold_Delivery))=0;
        %             Action_buy_or_sell(1+ID_H_deficit)=abs(E_H_deficit);
        %         else % only the MG demand can be met.
        %             Action_buy_or_sell(1)=abs(MG_Balance_daily_i); 
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver>Threshold_Delivery))=-(E_H_surplus_deliver(E_H_surplus_deliver>Threshold_Delivery))/eff_EVB_round-EV_travel-EV_travel_MG;
        %             Action_buy_or_sell(1+ID_H_surplus(E_H_surplus_deliver==Threshold_Delivery))=0;
        %             Action_buy_or_sell(1+ID_H_deficit)=abs(E_H_deficit_deliver)/sum(abs(E_H_deficit_deliver))*(sum(E_H_surplus_deliver)-abs(MG_Balance_daily_i));
        %         end 
        %     end
        %     EnergyBalance_after=EnergyBalance_before+Action_buy_or_sell;
        % end



end
end
% sum(EnergyBalance_after)-sum(EnergyBalance_before)