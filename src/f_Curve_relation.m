function [Cycle] = f_Curve_relation(DoD)
    % Define the table of DoD and corresponding Cycle Life (higher resolution)
    DoD_table = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100];
    Cycle_table = [NaN, 100000, 50000, 34142, 20000, 14142, 10000, 7500, 5000, 4000, 3000, 2500, 2000, 1750, 1500, 1350, 1200, 1100, 1000, 900, 800];
    
    % Interpolate the Cycle life for the given DoD
    Cycle = interp1(DoD_table, Cycle_table, DoD, 'linear', 'extrap');
end