function  [MG_Esurplus, MG_SoCB, MG_red_demand, MG_cut_prod, MG_B_e_cha_disch_int, MG_B_e_cha_disch_ext] = f_MG_OnlyBattery(MG_supply, MG_demand, MG_B, MG_SoCBmin, MG_SoCB0, MG_Bclimit, MG_Bdlimit, MG_eff_B_charge, MG_eff_B_dischg)
    % Initialize variables
    MG_Esurplus = zeros(size(MG_supply));
    MG_cut_prod = zeros(size(MG_supply)); 
    MG_red_demand = zeros(size(MG_supply));
    energy_needed = zeros(size(MG_supply));
    MG_SoCB = zeros(size(MG_supply)+1);
    MG_SoCB (1)= MG_SoCB0;
    MG_e_charge_int=zeros(size(MG_supply));  % used for calculating battery internal SOC and balance
    MG_e_discharge_int=zeros(size(MG_supply));
    MG_e_charge_ext=zeros(size(MG_supply));  % used for calculating battery internal SOC and balance
    MG_e_discharge_ext=zeros(size(MG_supply));  % used for calculating the cut down of electricity demand or curtail power surplus.

%%
    for i = 1:length(MG_supply) % Loop through each hour & ensure loop does not exceed array sizes
%%
        if MG_demand(i) < MG_supply(i)  % Depending on the balance of supply and demand charging/discharing of battery from the PV Check if demand is less than supply
           MG_Esurplus(i) = MG_supply(i) - MG_demand(i); % Calculate surplus energy for each hour
           if (MG_B*MG_SoCB(i))<MG_B %check if battery not fully charged
               MG_e_charge_int(i)=min([MG_Esurplus(i)*MG_eff_B_charge, MG_Bclimit, MG_B-(MG_B*MG_SoCB(i))]); %max possible energy battery can accept
               MG_e_charge_ext(i)=MG_e_charge_int(i)/MG_eff_B_charge;
               MG_SoCB(i+1) = MG_SoCB(i)+ (MG_e_charge_int(i)/ MG_B);  % Update state of charge                
               % MG_cut_prod(i)=MG_supply(i)-MG_demand(i)-(MG_e_charge_ext(i)*MG_eff_B_charge); %if only part of the surplus energy stored curtail production
               MG_cut_prod(i)=MG_supply(i)-MG_demand(i)-MG_e_charge_ext(i); %if only part of the surplus energy stored curtail production

           else 
                 MG_SoCB(i+1) = MG_SoCB(i);
                 MG_cut_prod(i) = MG_supply(i) - MG_demand(i); % Curtail PV production if Battery fully charged
            end
            
        else   % If demand is greater than to supply
                energy_needed(i) = (MG_demand(i) - MG_supply(i))/MG_eff_B_dischg;  % calculate the required energy from battery for balance
                e_discharge_bat_cont=min([MG_Bdlimit, ((MG_B*MG_SoCB(i)) - (MG_SoCBmin * MG_B))]); %max possible energy can be discharged from battery
                if  e_discharge_bat_cont>=energy_needed(i)
                    MG_e_discharge_int(i)=energy_needed(i);
                    MG_e_discharge_ext(i)=MG_e_discharge_int(i)*MG_eff_B_dischg;
                    MG_SoCB(i+1) = MG_SoCB(i)- (MG_e_discharge_int(i)/ MG_B); % Update state of charge
                    MG_red_demand(i) = 0; % Calculate the amount of demand that needs to be reduced to balance
                    
                else
                    MG_e_discharge_int(i)=e_discharge_bat_cont;
                    MG_e_discharge_ext(i)=MG_e_discharge_int(i)*MG_eff_B_dischg;
                    MG_SoCB(i+1) = MG_SoCB(i) - (MG_e_discharge_int(i)/ MG_B); % Update state of charge
                    MG_red_demand(i) = MG_demand(i) - MG_supply(i)-MG_e_discharge_ext(i); % Calculate the amount of energy which has to be reduced to balance
                end 
        end
     
    end
    MG_B_e_cha_disch_int=MG_e_charge_int-MG_e_discharge_int;
    MG_B_e_cha_disch_ext=MG_e_charge_ext-MG_e_discharge_ext;

end