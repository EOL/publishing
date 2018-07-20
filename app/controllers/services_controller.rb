require 'jwt'

class ServicesController < ApplicationController

  # I think this means respond only to accept: application/json
  # We might want HTML responses as well, and/or csv
  respond_to :json

  def authenticate_service
    # User needs to be logged in already!
    # Future: provide an automated service so scripts can fetch a token.
    # n.b. token only gives access to services, not to the rest of the
    # web site.
    if current_user
      if current_user.is_power_user?
        render json: {token: jwt_token(current_user)}
      else
        render_unauthorized errors: {forbidden: ["You are not authorized to use the web services."]}
      end
    else
      render_unauthenticated errors: {unauthorized: ["Please log in, then try again."]}
    end
  end

  protected

  # No args - act as a guard on any web service action that wants authentication
  # We check the encrypted_password in order to implement token retraction:
  # if the user changes their password, they will have to get a new token.
  # Returns user on success, nil (after render) on failure.

  def authorize_user_from_token!
    if current_user
      return render_unauthorized errors: {forbidden: ["You are not authorized to use the web services."]} \
         unless current_user.is_power_user?    # Unauthorized
      @current_user = current_user
    else
      the_claims = claims
      return render_unauthenticated errors: {unauthorized: ["Missing or invalid token."]} \
        unless the_claims    # Unauthenticated
      user = User.find_by_email(the_claims[0]['user'])
      return render_unauthenticated errors: {unauthorized: ["Invalid token."]} \
        unless user          # ill-formed token
      if user &&
         the_claims[0]['encrypted_password'] == user.encrypted_password
        return render_unauthorized errors: {forbidden: ["Invalid token."]} \
          unless user.is_power_user?    # Unauthorized
        @current_user = user
      end
    end
  end

  # Aux.  Sorry so pedantic, had to do some debugging
  def claims
    auth_header = request.headers['Authorization']
    if auth_header
      token = auth_header.split.last
      if token
        begin
          ::TokenAuthentication.decode(token)
        rescue JWT::DecodeError => e
          puts "? jwt decode error"
          nil
        end
      else
        puts "? no auth header last"
        nil
      end
    else
      puts "? no auth header"
      nil
    end
  # Rohit had `rescue nil` here
  end

  # Aux
  # The purpose of the password is just to cause tokens
  # to stop working whenever the user's password changes.
  def jwt_token(user)
    TokenAuthentication.encode({'user' => user.email,
                                'encrypted_password' => user.encrypted_password})
  end

  def render_unauthenticated(payload)
    render json: payload.merge(response: { status: 401 }), :status => 401
    nil
  end

  def render_unauthorized(payload)
    render json: payload.merge(response: { status: 403 }), :status => 403
    nil
  end

end
