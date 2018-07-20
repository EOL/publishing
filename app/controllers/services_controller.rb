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
        render json: { token: jwt_token(current_user) }
      else
        return render_unauthorized errors: { forbidden: ["You are not authorized to use the web services."] }
      end
    else
      return render_unauthorized errors: { unauthorized: ["Please log in, then try again."] }
    end
  end

  protected

  # No args - act as a guard on any web service action that wants authentication

  def authorize_user_from_token!
    if current_user
      raise "Forbidden" unless @current_user.is_power_user?    # Unauthorized
      @current_user = current_user
    else
      the_claims = claims
      raise "Unauthenticated" unless the_claims    # Unauthenticated
      if user = User.find_by(email: the_claims[0]['user']) and
         the_claims[0]['encrypted_password'] == user.encrypted_password
        raise "Forbidden" unless user.is_power_user?    # Unauthorized
        @current_user = user
      end
    end
  end

  # Aux
  def claims
    auth_header = request.headers['Authorization'] and
      token = auth_header.split(' ').last and
      ::TokenAuthentication.decode(token)
      # I don't know what the double-colon means
  rescue
    nil
  end

  # Aux
  # The purpose of the password is just to cause tokens
  # to stop working whenever the user's password changes.
  def jwt_token(user)
    TokenAuthentication.encode({'user' => user.email,
                                'encrypted_password' => user.encrypted_password})
  end

  def render_unauthorized(payload)
    render json: payload.merge(response: { code: 401 })
  end

end
