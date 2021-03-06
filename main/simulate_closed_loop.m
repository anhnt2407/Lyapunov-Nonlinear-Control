function simulate_closed_loop

global x t u delta_t
global V_dot_target V_dot_target_initial V dx_dot_du
global u_max u_min epoch stiff_system
global switched_Lyap
global f_at_u_0
global num_inputs num_states
global plant_file target_x target_history
global switching_threshold
global gamma % V2 step location
global LPF % Apply LPF if ==1
global filtered_u
global c % LPF parameter
global default_fully_actuated %Use the standard method or the method for integrators/underactuated systems?
global integral_gain

% Record the target for plotting later.
target_history(epoch,:) = eval(target_x);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Map out how system responds to control effort, according to model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

calc_partial_u_deriv % dx_dot_du is calculated


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calc D's: the sum of xi*dfi/du for each u
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

D= zeros(num_inputs,1);

if epoch > 1    % Let one epoch pass to accumulate a datapoint,
    % avoid an indexing error
    for i=1:num_inputs % Di = sum( xj*dfj/dui)
        for j=1:num_states
            D(i) = D(i)+(x(epoch-1,j)-target_history(epoch-1,j))*dx_dot_du(i,j);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Adjust the Lyapunov damping
% Less damping as we get closer to origin
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
V_dot_target = (V(epoch)/V(1))^2*V_dot_target_initial - integral_gain*V(epoch);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calc. u to force V_dot<0 at each grid point.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Let one data point accumulate w/ no control effort
if epoch == 1
    u(epoch,:) = zeros(num_inputs,1);
    
else % We're past the first epoch, go normally
    
    % Find the largest |D|
    % It will be the base for the u_i calculations.
    % If all D's are ~0, use V2.
    [M,max_D_index] = max(abs(D));
    
    if M > switching_threshold    % Use V1
        %u = (V_dot_target-sum(P))/sum(D);
        
        if (default_fully_actuated) % Normal calc., using all states
            P= (x(epoch,:)-target_history(epoch,:)).*f_at_u_0(1:num_states); % x_i*x_i_dot
        else % Only concerned with x1
            P= (x(epoch,1)-target_history(epoch,1)).*f_at_u_0(1); % x_1*x_1_dot
        end
        
        % One input -- simple formula
        if num_inputs == 1
            u(epoch)= (V_dot_target-sum(P)) / D;
        end
        
        
        % Multiple inputs -- more complicated formula
        
        if num_inputs > 1
            
            u(epoch,max_D_index) = (V_dot_target-sum(P)) / ...
                ( D(max_D_index) + (sum( D.*D )- D(max_D_index)^2) /...
                D(max_D_index) );
            if ~isfinite(u(1)) % If there was a divide by zero error
                u(epoch,max_D_index) = 0;
            end
            
            % Scale the other u's according to u_max*Di/D_max
            for i=1:num_inputs
                if i~= max_D_index % Skip this entry, we already did it
                    if abs(D(i)) > 0.1 % If this u has some effect
                        u(epoch,i) = u(max_D_index)*D(i)/D(max_D_index);
                        % Otherwise it will remain 0
                    end
                end
            end
        end
        
    else % All D's~0, so use V2
        % Log the switch
        for i=1:num_states
            switched_Lyap(epoch,i)=x(epoch,i); % In the true coordinate frame
        end
        
        dV2_dx = (x(epoch,:)-target_history(epoch,:))*...
            (0.9+0.1*tanh(gamma)+...
            0.05*sum( (x(epoch,:)-target_history(epoch,:)).^2)*sech(gamma)^2);
        
        % The first entry in dV2_dx is unique because the step is specified
        % in x1, so replace the previous
        dV2_dx(1) = (x(epoch,1)-target_history(epoch,1))*...
            (0.9+0.1*tanh(gamma))+...
            0.05*sum( (x(epoch,:)-target_history(epoch,:)).^2)*...
            ((x(epoch,1)-target_history(epoch,1))^-1*tanh(gamma)+...
            (x(epoch,1)-target_history(epoch,1))*sech(gamma)^2);
        
        if (default_fully_actuated) % Normal calc., using all states
            P_star = dV2_dx.*f_at_u_0(1:num_states);
        else  % only concerned with x1
            P_star = dV2_dx(1)*f_at_u_0(1);
        end
        
        D_star = zeros(num_inputs,1);
        %D_star(i) = dV2_dx(1)*dx_dot_du(1,1)+dV2_dx(2)*dx_dot_du(1,2);
        for i=1:num_inputs
            for j=1:num_states
                D_star(i) = D_star(i)+dV2_dx(j)*dx_dot_du(i,j);
            end
        end
        
        
        % The first input is unique
        u(epoch,1) = (V_dot_target-sum(P_star)) / ...
            ( D_star(1) + (sum( D_star.*D_star )- D_star(1)^2) /...
            D_star(1) );
        
        % For the other inputs
        for i=2:num_inputs
            u(epoch,i) = u(epoch,1)*D_star(i)/D_star(1);
        end
        
        % Check for NaN (caused by D_star(1)==0).
        % It means the system is likely uncontrollable.
        if ~isfinite( u(epoch,:) )
            disp('The system is likely uncontrollable at this point.')
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Apply LPF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if LPF == 1 % if user requested it
    % For each control effort, u
    for i=1 : num_inputs
        if epoch>2  % Let some data build up so we don't get (-) indices
            
            filtered_u(epoch,i) = (1/(1+c^2+1.414*c))*(...
                u(epoch-2,i)+2*u(epoch-1,i)+u(epoch,i)-...
                (c^2-1.414*c+1)*filtered_u(epoch-2,i)-...
                (-2*c^2+2)*filtered_u(epoch-1,i)...
                );
        else
            filtered_u(epoch,i) = u(epoch, i);
        end
    end
else % No LPF
    for i=1 : num_inputs
        filtered_u(epoch,i) = u(epoch, i);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check control effort saturation on filtered_u
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1: num_inputs
    if filtered_u(epoch,i) > u_max(i)
        filtered_u(epoch,i) = u_max(i);
    elseif filtered_u(epoch,i) < u_min(i)
        filtered_u(epoch,i) = u_min(i);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Simulate the plant. Get a new x-position
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_span= [t(epoch) t(epoch)+delta_t];
options=odeset('RelTol',1e-2,'AbsTol',1e-4,'NormControl','on',...
    'Vectorized','on');

if stiff_system
    [time, x_traj] = ode23s( str2func(plant_file), t_span,...
        [x(epoch,:)'; filtered_u(epoch,:)'], options );
else
    [time, x_traj] = ode23( str2func(plant_file), t_span,...
        [x(epoch,:)'; filtered_u(epoch,:)'], options );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Update quantities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

epoch=epoch+1; % Count another epoch

t(epoch) = time(end); % Update time for the next epoch


for i=1 : num_states
    x(epoch,i) = x_traj(end,i);
    
    V(epoch)= V(epoch)+0.5*(x(epoch,i)-target_history(epoch-1,i))^2;
end