class ServicesController < ApplicationController

  # I think this means respond only to accept: application/json
  # We might want HTML responses as well, and/or csv
  respond_to :json

  def authenticate_service
    # User needs to be logged in already!
    # Future: provide an automated service so scripts can fetch a token.
    # n.b. token only gives access to services, not to the rest of the
    # web site.
    render json: { token: jwt_token(@current_user) }
  end

  protected

  # No args - act as a guard on any web service action that wants authentication

  def authorize_user_from_token!
    if @current_user
      return @current_user
    end
    the_claims = claims
    if the_claims and
       user = User.find_by(email: the_claims[0]['user']) and
       the_claims[0]['encrypted_password'] = user.encrypted_password      
      if user.is_power_user?
        @current_user = user
      else
        # Unauthenticated
        return render_unauthorized errors: { unauthorized: ["Missing or invalid token."] }
      end
    else
      # Unauthorized
      return render_unauthorized errors: { forbidden: ["You are not authorized perform this action."] }
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
               # , 'encrypted_password' => user.encrypted_password
    TokenAuthentication.encode('user' => user.email)
  end

  def render_unauthorized(payload)
    render json: payload.merge(response: { code: 401 })
  end

end
