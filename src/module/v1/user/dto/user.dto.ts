import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsBooleanString,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPhoneNumber,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { PaginationDto } from '../../repository/dto/repository.dto';
import { UserRoleEnum } from '../../../../common/enums/user.enum';

export class CreateUserDto {
  @IsNotEmpty()
  @IsString()
  name: string;

  @IsNotEmpty()
  @IsEmail()
  @Transform(({ value }) => value.toLowerCase())
  email: string;

  @IsString()
  @IsPhoneNumber(null, { message: 'Please enter a valid phone number' })
  phone: string;

  @IsString()
  @MinLength(4)
  @MaxLength(20)
  password: string;

  @IsEnum([UserRoleEnum.TALENT, UserRoleEnum.ORGANIZATION])
  @IsNotEmpty()
  role: UserRoleEnum;

  @IsBoolean()
  @IsNotEmpty()
  termsAndConditionsAccepted: boolean;
}

export class ChangeEmailDto {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value.toLowerCase())
  newEmail: string;
}

export class CreateOrganizationDto extends CreateUserDto {
  @IsString()
  businessDescription: string;

  @IsString()
  businessLocation: string;

  @IsString()
  address: string;

  @IsString()
  city: string;

  @IsString()
  state: string;

  @IsString()
  country: string;
}
export class UpdatePasswordDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(4)
  @MaxLength(20)
  password: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(4)
  @MaxLength(20)
  newPassword: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(4)
  @MaxLength(20)
  confirmPassword: string;
}

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  username: string;

  @IsOptional()
  @IsString()
  firstName: string;

  @IsOptional()
  @IsString()
  lastName: string;

  @IsOptional()
  @IsString()
  @IsPhoneNumber()
  phone: string;

  @IsOptional()
  @IsString()
  bio: string;
}

export class CheckUsernameAvailableDto {
  @IsNotEmpty()
  @IsString()
  username: string;
}

export class AdminGetAllUsersDto extends PaginationDto {
  @IsOptional()
  @IsBooleanString()
  isDeleted: boolean;

  @IsEnum([UserRoleEnum.TALENT, UserRoleEnum.ORGANIZATION])
  @IsOptional()
  role?: UserRoleEnum;
}

export class VerifyGuestUserDto {
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @IsNumber()
  code: number;
}

export class UserAvailabilityDto {
  @IsOptional()
  @IsString()
  phone: string;

  @IsOptional()
  @IsEmail()
  @Transform(({ value }) => value.toLowerCase())
  email: string;
}

export class CreateWalletUserDto {
  @IsString()
  username?: string;

  @IsNotEmpty()
  @IsString()
  walletAddress: string;

  @IsString()
  @IsOptional()
  authSource?: string;

  @IsNotEmpty()
  @IsEnum([UserRoleEnum.TALENT, UserRoleEnum.ORGANIZATION])
  @IsString()
  role: UserRoleEnum;
}
