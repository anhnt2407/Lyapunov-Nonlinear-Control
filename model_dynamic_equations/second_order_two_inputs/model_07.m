function dx = model_07(t,x,u)


global num_inputs num_states

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Do not modify anything in this top section.

% Needs to return a (num_states + num_inputs) vector since the input is
% (num_states + num_inputs)-long.
% The final entries in the returned vector are meaningless.

% Pad the end of the vector to the right size.
for i=num_states+1 : num_states+num_inputs
    dx(i) = 0;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Van der Pol oscillator #2
dx(1)= x(2)+u(2);
dx(2)= -x(1)+(1-x(1)^2)*x(2)+2*u(1);
