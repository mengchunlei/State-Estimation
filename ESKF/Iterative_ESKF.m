function [delta_x, E] = Iterative_ESKF(H, R, f_b_ins, race_started, r_b_1, r_b_2, r_b_3, E_prev,delta_y, R_nb_hat, f_low, init, f_b_imu, omega_b_imu, g_n_nb, x_n_ins)
%ITERATIVE_EKSF Summary of this function goes here
%   Detailed explanation goes here


    deg2rad = pi/180;   
    
    Z3 = zeros(3,3);
    I3 = eye(3); 
    
    Tacc = 3600;
    Tars = 3600;
    
    h = 1/f_low; 
    
    p_n_ins = x_n_ins(1:3);
    v_n_ins = x_n_ins(4:6);
    bacc_b_ins = x_n_ins(7:9);
    q_n_ins = x_n_ins(10:13);
    q_n_ins = q_n_ins/norm(q_n_ins);
    bars_b_ins = x_n_ins(14:16);
    
    persistent P_hat Q  
    if init
%         std_pos = 2;
%         R_pos = std_pos^2*I3;
%         std_att = 1 * deg2rad;
%         R_att = std_att^2*I3;
%         std_vel = 1;
%         R_vel = std_vel^2*I3;
%         std_acc = 1;
%         R_acc = std_acc^2*I3;
%         R = blkdiag(R_pos , R_pos, std_vel^2, 2*R_pos, R_acc);


        std_acc = 0.01 * sqrt(10);
        %std_acc = 0.14 * 0.001 * 9.80665;
        Q_acc = std_acc * std_acc * I3; 
        std_acc_bias = 1;
        %std_acc_bias = 0.04 * 0.001 * 9.80665;
        Q_acc_bias = std_acc_bias * std_acc_bias * I3;

        std_ars = 0.1;
        %std_ars = 0.0035 * deg2rad;
        Q_ars = std_ars * std_ars * I3;
        std_ars_bias = 0.01 * sqrt(10);
        %std_ars_bias = 10 * deg2rad;
        Q_ars_bias = std_ars_bias * std_ars_bias * I3;

        Q = blkdiag( Q_acc, Q_acc_bias, Q_ars, Q_ars_bias ) * h * h;
        Q = 500 * Q;
        
        P_hat = diag([1e-1 * ones(1, 3) 1e-2 * ones(1, 3) 5e-2 * ones(1, 3) 1e-10 * ones(1, 3) 1e-6 * ones(1, 3) 1e-6 * ones(1, 3)]);  % Initial error covariance

       delta_x = 0;
       
    else
        
        A_dp = [Z3  I3  Z3  Z3  Z3  Z3];
        A_dv = [Z3  Z3  -R_nb_hat  -R_nb_hat*Smtrx(f_b_imu - bacc_b_ins)  Z3  I3];
        A_dbacc = [Z3  Z3  -(1/Tacc)*I3  Z3  Z3  Z3];
        A_dtheta = [Z3  Z3  Z3  -Smtrx(omega_b_imu - bars_b_ins)  -I3  Z3];
        A_dbars = [Z3  Z3  Z3  Z3  -(1/Tars)*I3  Z3];
        A_dg = [Z3  Z3  Z3  Z3  Z3  Z3];
          
        if (~race_started)
            % Do not estimate 
            A_dv = [Z3  Z3  -R_nb_hat  -R_nb_hat*Smtrx(f_b_imu - bacc_b_ins)  Z3  Z3];
        end
          
        A =  [A_dp ; A_dv ; A_dbacc ; A_dtheta ; A_dbars ; A_dg];


        % Discrete-time model
        Ad = eye(18) + h * A;

        E = [        Z3      Z3    Z3   Z3
              -R_nb_hat      Z3    Z3   Z3    % w_acc
                     Z3      I3    Z3   Z3    % w_acc_bias
                     Z3      Z3   -I3   Z3    % w_ars
                     Z3      Z3    Z3   I3  % w_ars_bias
                     Z3      Z3    Z3   Z3 ]; 
                  
        % Outlier Rejection
        [isOutlier,H] = ChiSquareTest(H, P_hat, R, delta_y);
        disp(isOutlier);
        
        if (~isOutlier)
            
            % KF gain
            K = P_hat * H' / (H * P_hat * H' + R);
            
            % corrector
            delta_x = K * delta_y;
            P_hat = (eye(18)-K*H) * P_hat * (eye(18) - K*H)' + K*R*K';
            
            % reset
            delta_theta = delta_x(10:12);
            G = [ I3 Z3 Z3                            Z3 Z3 Z3 
                  Z3 I3 Z3                            Z3 Z3 Z3
                  Z3 Z3 I3                            Z3 Z3 Z3
                  Z3 Z3 Z3 (I3 - Smtrx(0.5*delta_theta)) Z3 Z3
                  Z3 Z3 Z3                            Z3 I3 Z3
                  Z3 Z3 Z3                            Z3 Z3 I3];

            P_hat = G * P_hat * G';
             
            % covar predictor
            Qd = 0.5 * (Ad * E_prev * Q * E_prev' * Ad' + E * Q * E') * h;
            P_hat = Ad * P_hat * Ad' + Qd;
            P_hat = (P_hat + P_hat')/2;
            
        else
            
            delta_x = zeros(18,rank(delta_y));
            
        end
    end
        
        

end
