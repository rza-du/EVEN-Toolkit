function [Esurplus, SoCB, red_demand, cut_prod,B_e_charge_discharge] = f_BatteryOnly(supply, demand, B, SoCBmin,SoCB0, Bclimit, Bdlimit,eff_B_charge, eff_B_dischg )
    % Initialize variables
    Esurplus = zeros(size(supply));
    cut_prod = zeros(size(supply)); 
    red_demand = zeros(size(supply));
    energy_needed = zeros(size(supply));
    SoCB = zeros(size(supply)+1);
    SoCB (1)= SoCB0;
    e_charge=zeros(size(supply));
    e_discharge=zeros(size(supply));

    
%%
    for i = 1:min(length(supply), length(demand)) % Loop through each hour & ensure loop does not exceed array sizes
%%
        if demand(i) < supply(i)  % Depending on the balance of supply and demand charging/discharing of battery from the PV Check if demand is less than supply
           Esurplus(i) = supply(i) - demand(i); % Calculate surplus energy for each hour
           if (B*SoCB(i))<B %check if battery not fully charged
              e_charge(i)=min([Esurplus(i), Bclimit, B-(B*SoCB(i))])*eff_B_charge;%max possible energy battery can accept
              SoCB(i+1) = SoCB(i)+ (e_charge(i)/ B);  % Update state of charge                
              cut_prod(i)=supply(i)-demand(i)-e_charge(i); %if only part of the surplus energy stored curtail production
            else
                 SoCB(i+1) = SoCB(i);
                 cut_prod(i) = supply(i) - demand(i); % Curtail PV production if Battery fully charged
            end
            
        else   % If demand is greater than to supply
                energy_needed(i) = (demand(i) - supply(i)/eff_B_dischg);  % calculate the required energy from battery for balance
                e_discharge_bat_cont=min([Bdlimit, ((B*SoCB(i)) - (SoCBmin * B))])*eff_B_dischg; %max possible energy can be discharged from battery
                if  e_discharge_bat_cont>=energy_needed(i)
                    e_discharge(i)=energy_needed(i);
                    SoCB(i+1) = SoCB(i)- (e_discharge(i)/ B); % Update state of charge
                    red_demand(i) = 0; % Calculate the amount of demand that needs to be reduced to balance
                    
                else
                    e_discharge(i)=e_discharge_bat_cont/eff_B_dischg;
                    SoCB(i+1) = SoCB(i) - (e_discharge(i)/ B); % Update state of charge
                    red_demand(i) = demand(i) - supply(i)-e_discharge(i); % Calculate the amount of energy which has to be reduced to balance
                end
        end
     
    end
    
    B_e_charge_discharge=e_charge-e_discharge;

end