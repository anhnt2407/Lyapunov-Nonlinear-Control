function plots

% Plot a phase diagram.
% Plots the first 2 states if there are at least 2.
% If only 1 state, it plots x vs time

global x target_history epoch t u
global switched_Lyap num_states V

subplot(2,2,2); axis square; hold on
title('Closed Loop')

if num_states == 1
    % Starting point
    plot(0,x(1),'kx','markerSize',20)
    
    plot(t(1:epoch-1),switched_Lyap(1:epoch-1)', 'ms')
    
    plot(t(1:epoch-1),target_history(1:epoch-1)*ones(1,epoch-1),'rx');

    legend('Start','Alternative Lyapunov Funcion','Target',...
        'Location','southoutside','Orientation','Horizontal')
    
    plot(t(1:epoch-1),x(1:epoch-1))
    
    xlabel('Time')
    ylabel('x')
end

if num_states >= 2
    
    % Starting point
    plot(x(1,1), x(1,2),'kx','markerSize',20)
    
    % Targets
    plot(target_history(1:length(target_history),1),target_history(1:length(target_history),2),'rx','markerSize',20);
    
    % Trajectory where V2 is used
    plot(switched_Lyap(:,1), switched_Lyap(:,2), 'ms')
    
    
    legend('Start','Target','Alternative Lyapunov function',...
        'Location','southoutside','Orientation','Horizontal')

    % Trajectory where V1 is used
    plot( x(1:epoch,1), x(1:epoch,2), 'b' )
    xlabel('x_1')
    ylabel('x_2')

end

% Plot V_1(x)
subplot(2,2,3); axis square; hold on
title('Lyapunov Value')
plot(t(2:epoch),V(2:epoch),'b.')
xlabel('Time')
ylabel('Error, V_1(x)')

% Plot u
subplot(2,2,4); axis square; hold on
title('Control Effort u_1')
xlabel('Time')
ylabel('u_1')
plot(t(1:epoch-1),u(1:epoch-1))

plot_all_states
