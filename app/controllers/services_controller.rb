require 'jwt'

class ServicesController < ApplicationController

  # I think this means respond only to accept: application/json
  # We might want HTML responses as well, and/or csv
  respond_to :json

  # **** Maybe get rid of the authorization check here, and instead
  # **** make sure that it gets done in the authorize_user_from_token!
  # **** method?  No, better to fail fast.

  def authenticate_service
    # User needs to be logged in already!
    # Future: provide an automated service so scripts can fetch a token.
    # n.b. token only gives access to services, not to the rest of the
    # web site.
    if current_user
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

  # Authorize user for subsequent action if power user

  def authorize_user_from_token!
    user = authenticate_user_from_token!
    if user
      return render_unauthorized title: "Power user status is required for this operation." \
        unless user.is_power_user?    # Unauthorized
      @current_user = user
    end
  end

  def authorize_admin_from_token!
    user = authenticate_user_from_token!
    if user
      return render_unauthorized title: "Admin status is required for this operation." \
        unless user.is_admin?      # Unauthorized
      @current_user = user
    end
  end

  # No args - act as a guard on any web service action that wants authentication
  # We check the encrypted_password in order to implement token retraction:
  # if the user changes their password, they will have to get a new token.
  # Returns user on success, nil (after render) on failure.

  def authenticate_user_from_token!
    if current_user
      return render_unauthorized title: "You are not authorized to use the web services." \
         unless current_user.is_power_user?    # Unauthorized
      @current_user = current_user
    else
      diagnostic = check_claims
      if diagnostic
        return render_unauthenticated title: diagnostic
      else
        the_claims = claims
        user = User.find_by_email(the_claims[0]['user'])
        return render_unauthenticated title: "Invalid token." \
          unless user          # ill-formed token
        if user &&
           the_claims[0]['encrypted_password'] == user.encrypted_password
          user
        end
      end
    end
  end

  # Return the 'claims' or nil if not authorized
  def claims
    parts = request.headers['Authorization'].split
    ::TokenAuthentication.decode(parts[1])
  end

  # TBD: tests for all these cases... I've done them manually

  # Explain why authentication ('claims' above) would fail (if it would).
  def check_claims
    auth_header = request.headers['Authorization']
    if auth_header
      parts = auth_header.split
      if parts.size != 2
        "Expected Authorization header to have two parts, saw #{parts.size}: #{auth_header}"
      elsif parts[0] != 'JWT'
        "Expected Authorization header to start 'JWT', saw #{parts[0]}: #{auth_header}"
      else
        begin
          # Throw exception on failure; return nil on success
          ::TokenAuthentication.decode(parts[1])
          nil
        rescue JWT::DecodeError => e
          "JWT decode error in Authorization header: #{e}: #{parts[1]}"
        end
      end
    else
      "No Authorization header"
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
