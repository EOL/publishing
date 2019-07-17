require 'jwt'

class ServicesController < ApplicationController

  # I think this means respond only to accept: application/json
  # We might want HTML responses as well, and/or csv
  respond_to :json

  # **** Maybe get rid of the authorization check here, and instead
  # **** make sure that it gets done in the authorize_user_from_token!
  # **** method?  No, better to fail fast.

  # User-facing method for creating a token.

  def authenticate_service
    # User needs to be logged in already!
    # Future: provide an automated service so scripts can fetch a token.
    # n.b. token only gives access to services, not to the rest of the
    # web site.
    if current_user     # inherited from application_controller
      if current_user.is_power_user?
        render json: {token: jwt_token(current_user)}
      else
        render_unauthorized title: "You are not authorized to use the web services."
      end
    else
      render_unauthenticated title: "Please log in, then try again."
    end
  end

  protected

  # Authorize user for subsequent action if power user.
  # Returns user on success, nil on failure.

  def authorize_user_from_token!
    user = authenticate_user_from_token!
    return nil unless user
    if user.is_power_user?
      user
    else
      render_unauthorized title: "Power user status is required for this operation."
      nil
    end
  end

  def authorize_admin_from_token!
    user = authenticate_user_from_token!
    return nil unless user
    if user.is_admin?
      user
    else
      render_unauthorized title: "Admin status is required for this operation."
      nil
    end
  end

  # No args - act as a guard on any web service action that wants authentication.
  # We check the encrypted_password in order to implement token retraction:
  # if the user changes their password, they will have to get a new token.
  # Returns user on success, nil on failure after rendering an error report.

  def authenticate_user_from_token!
    the_claims = parse_claims
    if the_claims
      user = User.find_by_email(the_claims[0]['user'])
      # Valid email?
      # Password from time of token creation still current?
      if user && the_claims[0]['encrypted_password'] == user.encrypted_password
        user
      else
        render_unauthenticated title: "No such user, or token has been retracted."
        nil
      end
    elsif current_user
      current_user
    else
      render_unauthenticated title: "You must log in, or provide a token, to use the API."
      return nil
    end
  end

  # Returns nil on failure, syntactically correct claims on success.
  # TBD: tests for all these cases... I've done them manually

  def parse_claims
    # Check for presence of HTTP header
    auth_header = request.headers['Authorization']
    if not auth_header
      return nil
    end
    # See if header value splits into two parts
    parts = auth_header.split
    if parts.size != 2
      render_unauthenticated title: "Expected Authorization header to have two parts, saw #{parts.size}: #{auth_header}"
      return nil
    end
    # Part 0 has to be 'JWT'
    if parts[0] != 'JWT'
      render_unauthenticated title: "Expected Authorization header to start 'JWT', saw #{parts[0]}: #{auth_header}"
      return nil
    end
    # Decode the token
    begin
      claims = ::TokenAuthentication.decode(parts[1])
    rescue JWT::DecodeError => e
      render_unauthenticated title: "JWT decode error in Authorization header: #{e}: #{parts[1]}"
      return nil
    end
    claims
  end

  # Aux
  # The purpose of the password is just to cause tokens
  # to stop working whenever the user's password changes.
  def jwt_token(user)
    TokenAuthentication.encode({'user' => user.email,
                                'encrypted_password' => user.encrypted_password})
  end

  # The form of the payload is up for redesign; probably someone has
  # put forth a 'standard' way for services to report problems, but I
  # haven't found it yet.  Later.

  # e.g. perhaps http://jsonapi.org/format/#error-objects
  # which prescribes :title as the main way of giving the error message.

  def render_unauthenticated(payload)
    render json: payload.merge(:status => "401 Unauthenticated"), status: 401
    nil
  end

  def render_unauthorized(payload)
    render json: payload.merge(:status => "403 Unauthorized"), status: 403
    nil
  end

  def render_bad_request(payload)
    render json: payload.merge(:status => "400 Bad Request"), status: 400
    nil
  end

end
